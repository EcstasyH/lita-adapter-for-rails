module Lita
  module Adapters
      class Railschatbot < Adapter
      # insert adapter code here
      config :private_chat, default: false

      def initialize(robot)
        super

        self.user = User.create(1, name: "Shell User")
        
        logfile = File.new("dbread.log","r+")
        @last_read_id = logfile.gets.to_i
        logfile.close

        @uid =0
      end

      # rubocop:disable Lint/UnusedMethodArgument

      # Returns the users in the room, which is only ever the "Shell User."
      # @param room [Lita::Room] The room to return a roster for. Not used in this adapter.
      # @return [Array<Lita::User>] The users in the room.
      # @since 4.4.0
      def roster(room)
        [user]
      end

      # rubocop:enable Lint/UnusedMethodArgument

      # Displays a prompt and requests input in a loop, passing the incoming messages to the robot.
      # @return [void]
      def run
        room = robot.config.adapters.shell.private_chat ? nil : "shell"
        @source = Source.new(user: user, room: room)
        robot.trigger(:connected)

        run_loop
      end

      # Outputs outgoing messages to the shell.
      # @param _target [Lita::Source] Unused, since there is only one user in the
      #   shell environment.
      # @param strings [Array<String>] An array of strings to output.
      # @return [void]
      def send_messages(_target, strings)
        strings = Array(strings)
        strings.reject!(&:empty?)
        unless RbConfig::CONFIG["host_os"] =~ /mswin|mingw/ || !$stdout.tty?
          strings.map! { |string| "#{string}" }
        end
        #
        @db = SQLite3::Database.open "../db/development.sqlite3"
        @db.results_as_hash = true
        rs = @db.execute "SELECT * FROM messages" 

        from_bot = 1
        new_id = rs.last[0]+1
        @db.execute "INSERT INTO messages VALUES('#{new_id}','#{strings}','#{from_bot}','#{@uid}','#{Time.now}','#{Time.now}')"
      end

      # Adds a blank line for a nice looking exit.
      # @return [void]
      def shut_down
        puts
      end

      private

      attr_accessor :user

      def build_message(input, source)
        message = Message.new(robot, input, source)
        message.command! if robot.config.adapters.shell.private_chat
        message
      end

      def normalize_history(input)
        if input == "" || (Readline::HISTORY.size >= 2 && input == Readline::HISTORY[-2])
          Readline::HISTORY.pop
        end
      end

      def normalize_input(input)
        input.chomp.strip
      end
      
      #modified
      def collect_and_send 
        @db = SQLite3::Database.open "../db/development.sqlite3"
        
        @db.results_as_hash = true
        stm = @db.prepare "SELECT * FROM messages WHERE Id>?"
        stm.bind_param 1, @last_read_id
        rs = stm.execute
        
        a = Array.new
        rs.each do |row| 
            m = Hash["id"=> row['id'], 'body' => row['body'], 'from_bot'=> row['from_bot'], 'user_id'=>row['user_id'] ]
            a << m
        end
        
        #close 
        stm.close if stm
        @db.close if @db

        a.each do |row|
          @uid = row['user_id']
          input = row['body']
          @last_read_id = row['id']
          
          if row['from_bot']==true
            next
          end
          robot.receive(build_message(input, @source))
        end

        record_read_id        
      end

      #modified
      def run_loop
        loop do
          collect_and_send
          sleep(1)
        end
      end 

      def record_read_id
        logfile = File.new("dbread.log","w+")
        logfile.syswrite(@last_read_id.to_s)
        logfile.close
      end

      Lita.register_adapter(:railschatbot, self)
    end
  end
end
