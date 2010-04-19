module Gravy
  module Service
    class << self
      PATH_FILTER = Regexp.new("^'?/*([a-zA-Z0-9][a-zA-Z0-9@._-])*'?$")

      def run
        # handle it
        args = handle_request

        # run it!
        ENV['REMOTE_USER_ID'] = ARGV[0]
        system(*args)
      end

      def handle_request
        command = ENV['SSH_ORIGINAL_COMMAND']
        path = ''
        type = :unknown

        if command =~ /^git[\s|\-]/
          handle_git(command)
        elsif command =~ /^hg\s/
          handle_hg(command)
        else
          raise 'Command not allowed'
        end
      end

      def handle_git(command)
        match = command.scan(/(git[\s\-](upload|receive)-pack)\s(.+)/).first
        raise 'Unable to process' unless match
        command, access, path = match

        # determine type of access requested
        access = case access
        when 'upload'  then :read
        when 'receive' then :write
        else raise 'Command not allowed'
        end

        # strip .git off the path
        path = path.gsub(/\.git(')?/, '\1')

        # process request
        process(path, access)

        # command to execute
        [command, "#{path}.git"]
      end

      def handle_hg(command)
        match = command.scan(/(hg\s-R\s(.+)\sserve\s--stdio)/).first
        raise "Unable to process" unless match
        command, path = match

        # process request
        project = process(path, :write)

        # command to execute
        ["hg", "-R", "#{path}", "serve", "--stdio"]
      end

      def process(path, access)
        # process
        project = find_project(path)
        check_access(user, project, access)

        project
      end

      def find_project(requested_path)
        # get the requesting user
        user = User.get(ARGV[0])
        raise 'Invalid user' unless user

        # check the path requested
        match = PATH_FILTER.match(requested_path)
        raise 'Unsafe arguments' unless match && match[1] && !match[1].empty?
        safepath = match[1]

        projectpath
      end

      def check_access(user, project, type)
        # TODO need access storage
        return true if user && project
        raise 'Access denied'
      end
    end
  end
end
