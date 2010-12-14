require "mongoid"

module Mongoid
	module Acts
		module Tree
			def self.included(model)
				model.class_eval do
					extend InitializerMethods
				end
			end

			module InitializerMethods
				def acts_as_tree(options = {})
					options = {
						:parent_id_field => "parent_id",
						:path_field      => "path",
						:depth_field     => "depth",
						:class           => self
					}.merge(options)

					write_inheritable_attribute :acts_as_tree_options, options
					class_inheritable_reader :acts_as_tree_options

					include InstanceMethods
					include Fields
					extend Fields
					extend ClassMethods

					field parent_id_field, :type => BSON::ObjectId
					field path_field, :type => Array,  :default => [], :index => true
					field depth_field, :type => Integer, :default => 0

					self.class_eval do
						define_method "#{parent_id_field}=" do | new_parent_id |
						  if new_parent_id.present?
								new_parent = acts_as_tree_options[:class].find new_parent_id
								new_parent.children.push self, false
							else
								self.write_attribute parent_id_field, nil
								self[path_field] = []
								self[depth_field] = 0
						  end
						end
					end

					after_save      :move_children
					validate        :will_save_tree
					before_destroy  :destroy_descendants
				end
			end

			module ClassMethods
				def roots
					self.where(parent_id_field => nil).order_by tree_order
				end
			end

			module InstanceMethods
				def [](field_name)
					self.send field_name
				end

				def []=(field_name, value)
					self.send "#{field_name}=", value
				end

				def ==(other)
					return true if other.equal?(self)
					return true if other.kind_of?(acts_as_tree_options[:class]) and other._id == self._id
					false
				end

				def will_save_tree
					if @_cyclic
						errors.add(:base, "Can't be children of a descendant")
					end
				end

				def fix_position
					if parent.nil?
						self.write_attribute parent_id_field, nil
						self[path_field] = []
						self[depth_field] = 0
					else
						self.write_attribute parent_id_field, parent._id
						self[path_field] = parent[path_field] + [parent._id]
						self[depth_field] = parent[depth_field] + 1
						self.save
					end
				end

				def parent
					@_parent or (self[parent_id_field].nil? ? nil : acts_as_tree_options[:class].find(self[parent_id_field]))
				end

				def root?
					self[parent_id_field].nil?
				end

				def root
					self[path_field].first.nil? ? self : acts_as_tree_options[:class].find(self[path_field].first)
				end

				def ancestors
					return [] if root?
					acts_as_tree_options[:class].where(:_id.in => self[path_field]).order_by(depth_field)
				end

				def self_and_ancestors
					ancestors << self
				end

				def siblings
					acts_as_tree_options[:class].where(:_id.ne => self._id, parent_id_field => self[parent_id_field]).order_by tree_order
				end

				def self_and_siblings
					acts_as_tree_options[:class].where(parent_id_field => self[parent_id_field]).order_by tree_order
				end

				def children
					Children.new self
				end

				def children=(new_children_list)
					self.children.clear
					new_children_list.each do | child |
						self.children << child
					end
				end

				alias replace children=

				def descendants
					# workorund for mongoid unexpected behavior
					return [] if !!self.instance_variable_get(:@new_record)
					acts_as_tree_options[:class].all_in(path_field => [self._id]).order_by tree_order
				end

				def self_and_descendants
					[self] + self.descendants
				end

				def is_ancestor_of?(other)
					other[path_field].include?(self._id)
				end

				def is_or_is_ancestor_of?(other)
					(other == self) or is_ancestor_of?(other)
				end

				def is_descendant_of?(other)
					self[path_field].include?(other._id)
				end

				def is_or_is_descendant_of?(other)
					(other == self) or is_descendant_of?(other)
				end

				def is_sibling_of?(other)
					(other != self) and (other[parent_id_field] == self[parent_id_field])
				end

				def is_or_is_sibling_of?(other)
					(other == self) or is_sibling_of?(other)
				end

				def move_children

					if @_will_move
						@_will_move = false
						self.children.each do | child |
							child.fix_position
							child.save
						end
						@_will_move = true
					end
				end

				def destroy_descendants
					self.descendants.each &:destroy
				end
			end

			#proxy class
			class Children < Array
				#TODO: improve accessors to options to eliminate object[object.parent_id_field]

				def initialize(owner)
					@parent = owner
					self.concat find_children_for_owner.to_a
				end

				#Add new child to list of object children
				def <<(object, will_save=true)
					if object.descendants.include? @parent
						object.instance_variable_set :@_cyclic, true
					else
						object.write_attribute object.parent_id_field, @parent._id
						object[object.path_field] = @parent[@parent.path_field] + [@parent._id]
						object[object.depth_field] = @parent[@parent.depth_field] + 1
						object.instance_variable_set :@_will_move, true
						object.save if will_save
					end

					super(object)
				end

				def build(attributes)
					child = @parent.class.new(attributes)
					self.push child
					child
				end

				alias create build

				alias push <<

				#Deletes object only from children list.
				#To delete object use <tt>object.destroy</tt>.
				def delete(object_or_id)
					object = case object_or_id
						when String, BSON::ObjectId
							@parent.class.find object_or_id
						else
							object_or_id
					end

					object.write_attribute object.parent_id_field, nil
					object[object.path_field]      = []
					object[object.depth_field]     = 0
					object.save

					super(object)
				end

				#Clear children list
				def clear
					self.each do | child |
						@parent.children.delete child
					end
				end

				private

				def find_children_for_owner
					@parent.class.where(@parent.parent_id_field => @parent.id).
						order_by @parent.tree_order
				end

			end

			module Fields
				def parent_id_field
					acts_as_tree_options[:parent_id_field]
				end

				def path_field
					acts_as_tree_options[:path_field]
				end

				def depth_field
					acts_as_tree_options[:depth_field]
				end

				def tree_order
					acts_as_tree_options[:order] or []
				end
			end
		end
	end
end

