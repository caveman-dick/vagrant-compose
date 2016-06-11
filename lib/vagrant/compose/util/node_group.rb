require_relative "node"

module VagrantPlugins
  module Compose

    # This class defines a group of nodes, representig a set of vagrant machines with similar characteristics.
    # Nodes will be composed by NodeGroup.compose method, according with the configuration of values/value_generator
    # of the group of node itself.
    class NodeGroup

      # A number identifying the group of nodes withing the cluster.
      attr_reader :index

      # The name of the group of nodes
      attr_reader :name

      # The number of nodes/instances to be created in the group of nodes.
      attr_reader :instances

      # The value/value generator to be used for assigning to each node in this group a vagrant base box to be used for creating vagrant machines implementing nodes in this group.
      attr_accessor :box

      # The value/value generator to be used for assigning to each node in this group a box name a.k.a. the name for the machine in VirtualBox/VMware console.
      attr_accessor :boxname

      # The value/value generator to be used for assigning to each node in this group a unique hostname
      attr_accessor :hostname

      # The value/value generator to be used for assigning to each node in this group a unique list of aliases a.k.a. alternative host names
      attr_accessor :aliases

      # The value/value generator to be used for assigning to each node in this groupa unique ip
      attr_accessor :ip

      # The value/value generator to be used for assigning to each node in this group cpus
      attr_accessor :cpus

      # The value/value generator to be used for assigning to each node in this group memory
      attr_accessor :memory

      # The value/value generator to be used for assigning each node in this group to a list of ansible groups
      attr_accessor :ansible_groups

      # The value/value generator to be used for assigning a dictionary with custom attributes - Hash(String, obj) - to each node in this group.
      attr_accessor :attributes

      def initialize(index, instances, name)
        @index  = index
        @name = name
        @instances = instances
      end

      # Composes the group of nodes, by creating the required number of nodes
      # in accordance with values/value_generators.
      # Additionally, some "embedded" trasformation will be applied to attributes (boxname, hostname) and
      # some "autogenerated" node properties will be computed (fqdn).
      def compose(cluster_name, cluster_domain, cluster_offset)
        node_index = 0
        while node_index < @instances
          box            = generate(:box, @box, node_index)
          boxname        = maybe_prefix(cluster_name,
                                        "#{generate(:boxname, @boxname, node_index)}")
          hostname       = maybe_prefix(cluster_name,
                                        "#{generate(:hostname, @hostname, node_index)}")
          aliases        = generate(:aliases, @aliases, node_index).join(',')
          fqdn           = cluster_domain.empty? ? "#{hostname}" : "#{hostname}.#{cluster_domain}"
          ip             = generate(:ip, @ip, node_index)
          cpus           = generate(:cpus, @cpus, node_index)
          memory         = generate(:memory, @memory, node_index)
          ansible_groups = generate(:ansible_groups, @ansible_groups, node_index)
          attributes     = generate(:attributes, @attributes, node_index)
          yield Node.new(box, boxname, hostname, fqdn, aliases, ip, cpus, memory, ansible_groups, attributes, cluster_offset + node_index, node_index)

          node_index += 1
        end
      end

      # utility function for concatenating cluster name (if present) to boxname/hostname
      def maybe_prefix(cluster_name, name)
        if cluster_name && cluster_name.length > 0
          "#{cluster_name}-" + name
        else
          name
        end
      end

      # utility function for resolving value/value generators
      def generate(var, generator, node_index)
        unless generator.respond_to? :call
          return generator
        else
          begin
            return generator.call(@index, @name, node_index)
          rescue Exception => e
            raise VagrantPlugins::Compose::Errors::AttributeExpressionError, :message => e.message, :attribute => var, :node_index => node_index, :node_group_name => name
          end
        end
      end
    end

  end
end
