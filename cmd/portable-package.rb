# frozen_string_literal: true

require "cli/parser"

module Homebrew
  include FileUtils

  module_function

  def portable_package_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `portable-package` <formulae>

        Build and package portable formulae.
      EOS
      switch "--no-uninstall-deps",
             description: "Don't uninstall all dependencies of portable formulae before testing."
      switch "-v", "--verbose",
             description: "Pass `--verbose` to `brew` commands."
      named_args :formula, min: 1
    end
  end

  def portable_package
    args = portable_package_args.parse

    ENV["HOMEBREW_DEVELOPER"] = "1"

    p `ls -l /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps`
    p `ls -l /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/bo98`
    p `ls -l /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/bo98/homebrew-portable-ruby`
    p `ls -l /home/linuxbrew/.linuxbrew/Homebrew/Library/Taps/bo98/homebrew-portable-ruby/.git`

    verbose = []
    verbose << "--verbose" if args.verbose?
    verbose << "--debug" if args.debug?

    # If test-bot cleanup is performed and auto-updates are disabled, this might not already be installed.
    safe_system "brew", "install", "ca-certificates" unless DevelopmentTools.ca_file_handles_most_https_certificates?

    args.named.each do |name|
      name = "portable-#{name}" unless name.start_with? "portable-"
      begin
        # On Linux, install glibc@2.13 from bottle but don't install its dependencies.
        deps = Dependency.expand(Formula[name], cache_key: "portable-package-#{name}") do |_dependent, dep|
          Dependency.prune if dep.test? || dep.optional?

          next if dep == "glibc@2.13"

          Dependency.keep_but_prune_recursive_deps
        end.map(&:name)

        bottled_deps, deps = deps.partition { |dep| dep == "glibc@2.13" }

        safe_system "brew", "install", "--debug", *verbose, *bottled_deps

        # Build bottles for all other dependencies.
        safe_system "brew", "install", "--build-bottle", *verbose, *deps

        safe_system "brew", "install", "--build-bottle", *verbose, name
        unless args.no_uninstall_deps?
          safe_system "brew", "uninstall", "--force", "--ignore-dependencies", *verbose, *deps
        end
        safe_system "brew", "test", *verbose, name
        puts "Linkage information:"
        safe_system "brew", "linkage", *verbose, name
        bottle_args = %w[
          --skip-relocation
          --root-url=https://ghcr.io/v2/homebrew/portable-ruby
          --json
          --no-rebuild
        ]
        safe_system "brew", "bottle", *verbose, *bottle_args, name
        Pathname.glob("*.bottle*.tar.gz") do |bottle_filename|
          bottle_file = bottle_filename.realpath
          bottle_cache = HOMEBREW_CACHE/bottle_filename
          ln bottle_file, bottle_cache, force: true
        end
      rescue => e
        ofail e
      end
    end

    Pathname.glob("*.bottle*.tar.gz") do |bottle_filename|
      bottle_cache = HOMEBREW_CACHE/bottle_filename
      rm_f bottle_cache
    end
  end
end
