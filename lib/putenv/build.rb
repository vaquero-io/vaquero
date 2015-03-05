module Putenv
  # Instantiates the platform
  # builds the environment hash then
  # passes to provider plugin
  class Build < Thor::Group
    include Thor::Actions

    # Build subcommand arguments and options
    # rubocop:disable LineLength
    argument :env, type: :string, desc: DESC_BUILD
    class_option :all, type: :boolean, aliases: '-a', desc: DESC_BUILD_ALL
    class_option :component, type: :string, aliases: '-c', desc: DESC_BUILD_COMPONENT
    class_option :node, type: :string, aliases: '-n', desc: DESC_BUILD_NODE
    class_option :named_nodes, type: :boolean, default: true
    class_option :verbose, type: :boolean, aliases: '-v', default: false
    class_option :provider, type: :string, aliases: '-p'
    class_option :verify_ssl, type: :boolean, default: true
    class_option :provider_username, type: :string, default: nil
    class_option :provider_password, type: :string, default: nil
    class_option :provider_options, type: :string, default: nil

    # TODO: we don't have a tier definition any longer
    # class_option :tier, type: :string, aliases: '-t', desc: DESC_BUILD_TIER
    # TODO: Concurrency is an aspect of the provisioner not the tool so somehow you
    # have to find a way to pass/set any kind of provider required options that is plugin agnostic
    # class_option :concurrency, type: :numeric, aliases: '-C', default: 8, desc: DESC_BUILD_CONCURRENCY
    # TODO: What to do about logfiles?
    # class_option :logfiles, type: :string, aliases: '-l', default: 'logs', desc: DESC_BUILD_LOGFILES
    # rubocop:enable LineLength

    def self.source_root
      File.dirname(__FILE__)
    end

    def build
      # TODO: Initially, i am just passing the entire
      # environment hash to the plugin
      # But this can be further broken down based on parameters passed to build
      provider = options[:provider] ? Putenv::Provider.new(options[:provider]) : nil

      plat = Putenv::Platform.new(provider)

      env_build = plat.environment(env)
      puts "Platform:    #{plat.product}"
      puts "Environment: #{env_build['environment']}"

      # here we figure out what to cut

      # If we're requesting a single component, we'll just do that.
      if options[:component]
        comp = options[:component]
        puts "Component:   #{comp}"
        unless env_build['components'][comp]
          fail(IOError, "Requested component #{comp} not found in environment #{env}")
        end
        env_build['components'] = { comp => env_build['components'][comp] }
        if options[:node]
          node_list = []
          options[:node].split(/,/).each do |n|
            node_list << env_build['components'][comp]['nodes'][n.to_i - 1]
          end

          puts "Nodes:"
          node_list.each { |n| puts " - #{n}" }

          env_build['components'][comp]['nodes'] = node_list
          env_build['components'][comp]['count'] = node_list.size
        end
      end

      # Parse provider options from key1=val1,key2=val2 to a hash
      provider_options = {}
      options[:provider_options].split(/,/).each do |keyval|
        key, value = keyval.split(/=/)
        provider_options[key] = value
      end if options[:provider_options]

      # Provision
      provider_options = {
        username:    options[:provider_username],
        password:    options[:provider_password],
        named_nodes: options[:named_nodes],
        verify_ssl:  options[:verify_ssl]
      }.merge(provider_options)

      plat.provision(env_build, provider_options)
    end
  end
end
