# frozen_string_literal: true

# rubocop: disable Metrics/AbcSize, Metrics/CyclomaticComplexity
# rubocop: disable Metrics/MethodLength, Metrics/PerceivedComplexity
module BrowserslistUseragent
  # Resolves user agent string to {family, version} hash
  class Resolver
    attr_reader :user_agent_string

    def initialize(user_agent_string)
      @user_agent_string = user_agent_string
    end

    def call
      agent = self.class.user_agent_parser.parse(user_agent_string)

      family = agent.family
      version = VersionNormalizer.new(agent.version.to_s).call

      # Case A: For Safari, Chrome and others browsers on iOS
      # that report as Safari after stripping tags
      family = 'iOS' if agent.family.include?('Safari') && agent.os.family == 'iOS'

      # Case B: The browser on iOS didn't report as safari,
      # so we use the iOS version as a proxy to the browser
      # version. This is based on the assumption that the
      # underlying Safari Engine used will be *atleast* equal
      # to the iOS version it's running on.
      if agent.os.family == 'iOS'
        return {
          family: 'iOS',
          version: VersionNormalizer.new(agent.os.version.to_s).call
        }
      end

      # Case C: The caniuse database does not contain
      # historical browser versions for so called `minor`
      # browsers like Chrome for Android, Firefox for Android etc
      # In this case, we proxy to the desktop version
      # @see https://github.com/Fyrd/caniuse/issues/3518
      family = 'Chrome' if agent.family.include?('Chrome Mobile')
      family = 'Chrome' if agent.family == 'HeadlessChrome'
      family = 'Edge' if agent.family == 'Edge Mobile'
      family = 'Explorer' if agent.family == 'IE'
      family = 'ExplorerMobile' if agent.family == 'IE Mobile'
      family = 'Firefox' if agent.family == 'Firefox Mobile'
      family = 'OperaMobile' if agent.family == 'Opera Mobile'
      family = 'QQAndroid' if agent.family == 'QQ Browser Mobile'
      family = 'SamsungInternet' if agent.family == 'Samsung Internet'
      family = 'UCAndroid' if agent.family == 'UC Browser'

      # Case D: Access from some app browsers resolves to the app's family,
      # which are not included in the caniuse database,
      # even though they use Blink/Chromium rendering engine
      # In this case, the family is set to Chrome with the corresponding version
      if %w[Facebook Instagram].include? agent.family
        return {
          family: 'Chrome',
          version: VersionNormalizer.new(user_agent_string[/(?<=Chrome\/)[^ ]*/]).call
        }
      end

      { family: family, version: version }
    end

    def self.user_agent_parser
      @user_agent_parser ||= UserAgentParser::Parser.new
    end
  end
end
# rubocop: enable Metrics/AbcSize, Metrics/CyclomaticComplexity
# rubocop: enable Metrics/MethodLength, Metrics/PerceivedComplexity
