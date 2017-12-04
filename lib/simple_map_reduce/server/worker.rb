module SimpleMapReduce
  module Server
    class Worker
      attr_reader :id
      attr_reader :url
      attr_reader :status
      
      STATUS = {
        ready: 0,
        reserved: 1,
        working: 2
      }.freeze

      STATUS.keys.each do |status|
        define_method "#{status.to_s}!".to_sym do
          @status = STATUS[status]
        end

        define_method "#{status.to_s}?".to_sym do
          @status == STATUS[status]
        end
      end
    
      def initialize(url:)
        @url = url
        @status = STATUS[:ready]
      end

      def id
        @id ||= self.object_id
      end
      
      def to_h
        {
          id: id,
          url: @url,
          status: @status
        }
      end
    end
  end
end
