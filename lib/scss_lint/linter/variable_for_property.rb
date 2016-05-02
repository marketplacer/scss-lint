module SCSSLint
  # Reports the use of literals for properties where variables are prefered.
  class Linter::VariableForProperty < Linter
    include LinterRegistry

    DEFAULT_IGNORED_VALUES = %w[currentColor inherit initial transparent].freeze

    def visit_root(_node)
      @properties = Set.new(config['properties'])
      @ignored_values = Set.new(config['ignored_values'] || DEFAULT_IGNORED_VALUES).map(&:to_s)
      yield if @properties.any?
    end

    def visit_prop(node)
      property_name = node.name.join
      return unless @properties.include?(property_name)
      invalid = [node.children.map { |child| invalid?(child) }].flatten.compact
      return if invalid.length == 0
      add_lint(node, "Property #{property_name} should use " \
                     "a variable rather than '#{invalid.join}'")
    end

  private

    def invalid?(node)
      case node
      when Sass::Script::Tree::Variable
        nil
      when Sass::Script::Tree::ListLiteral
        node.children.map { |child| invalid?(child) }
      when Sass::Script::Tree::Literal
        return nil if ignored_value?(node)
        node.value.to_s
      when Sass::Script::Tree::UnaryOperation
        invalid?(node.operand)
      when Sass::Script::Tree::Funcall
        node.args.map { |arg| invalid?(arg) }
      when Sass::Script::Tree::Operation
        invalid = [invalid?(node.operand1), invalid?(node.operand2)].compact
        case node.operator
        when :plus, :minus
          invalid if invalid.any?
        else
          invalid if invalid.length == 2 # allow $variable * 100
        end
      when Sass::Script::Tree::Interpolation
        nil # too hard
      end
    end

    def variable_property_with_important?(value)
      value.is_a?(Sass::Script::Tree::ListLiteral) &&
        value.children.length == 2 &&
        value.children.first.is_a?(Sass::Script::Tree::Variable) &&
        value.children.last.value.value == '!important'
    end

    def ignored_value?(node)
      node.respond_to?(:value) &&
        @ignored_values.include?(node.value.to_s)
    end
  end
end
