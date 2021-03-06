require 'nokogiri'

module RDF
  ##
  # **`RDF::All`** Attempts to read and parse all formats.
  #
  # Documentation
  # -------------
  #
  # * {RDF::All::Format}
  # * {RDF::All::Reader}
  # * {RDF::NTriples::Writer}
  #
  # @example Requiring the `RDF::All` module explicitly
  #   require 'rdf/all'
  module All
    class << self
      attr_accessor :debug
      def debug?; @debug; end
    end

    ##
    # Only matched with :format => :all
    class Format < RDF::Format
      reader { RDF::All::Reader }
    end
    
    ##
    # Generic reader, detects appropriate readers and passes to each one
    class Reader < RDF::Reader
      ##
      # Returns the base URI determined by this reader.
      #
      # @attr [RDF::URI]
      attr_reader :base_uri

      ##
      # Returns a hash of the number of statements parsed by each reader.
      #
      # @attr [Hash<Class, Integer>] statement_count
      attr :statement_count

      ##
      # Finds each appropriate reader and yields statements
      # from each reader found.
      #
      # Take a sample from the input and pass to each Reader which implements
      # a .detect class method
      #
      # @overload each_statement
      #   @yield  [statement]
      #     each statement
      #   @yieldparam  [RDF::Statement] statement
      #   @yieldreturn [void] ignored
      #   @return [void]
      #
      # @overload each_statement
      #   @return [Enumerator]
      #
      # @return [void]
      # @see    RDF::Enumerable#each_statement
      def each_statement(&block)
        if block_given?
          logger = @options[:logger] ||= begin
            logger = Logger.new(STDOUT)  # In case we're not invoked from rack
            logger.level = ::RDF::All.debug? ? Logger::DEBUG : Logger::INFO
            logger
          end

          options = @options.dup
          options[:content_type] ||= @input.content_type if @input.respond_to?(:content_type)
          options.delete(:format) if options[:format] == :all
          reader_class = RDF::Reader.for(options[:format] || options) || RDF::RDFa::Reader
          logger.debug "detected #{reader_class.name}"

          statement_count = 0
          reader_class.new(@input, @options) do |reader|
            reader.each_statement do |statement|
              statement_count += 1
              block.call(statement)
            end
            @base_uri ||= reader.base_uri unless reader.base_uri.to_s.empty?
          end
          logger.info "parsed #{statement_count.to_i} triples from #{reader_class.name}"
        end
        enum_for(:each_statement)
      end

      ##
      # Iterates the given block for each RDF triple.
      #
      # If no block was given, returns an enumerator.
      #
      # Triples are yielded in the order that they are read from the input
      # stream.
      #
      # @overload each_triple
      #   @yield  [subject, predicate, object]
      #     each triple
      #   @yieldparam  [RDF::Resource] subject
      #   @yieldparam  [RDF::URI]      predicate
      #   @yieldparam  [RDF::Term]     object
      #   @yieldreturn [void] ignored
      #   @return [void]
      #
      # @overload each_triple
      #   @return [Enumerator]
      #
      # @return [void]
      # @see    RDF::Enumerable#each_triple
      def each_triple(&block)
        if block_given?
          each_statement do |statement|
            block.call(statement.to_triple)
          end
        end
        enum_for(:each_triple)
      end
    end
  end
end # RDF
