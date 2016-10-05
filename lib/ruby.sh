# -*- mode: bash; tab-width: 2; -*-
# vim: ts=2 sw=2 ft=bash noet

# source nodejs
. ${engine_lib_dir}/nodejs.sh

# Determine the ruby runtime to install. This will first check
# within the Boxfile, then will rely on default_runtime to
# provide a sensible default
ruby_runtime() {
  echo $(nos_validate \
    "$(nos_payload "config_ruby_runtime")" \
    "string" "$(default_ruby_runtime)")
}

# Provide a default ruby version.
default_ruby_runtime() {
  gem_runtime=$(gemfile_runtime)

  if [[ "$gem_runtime" = "false" ]]; then
    echo "ruby-2.2"
  else
    echo $gem_runtime
  fi
}

# todo: extract the contents of Gemfile
gemfile_runtime() {
  echo "false"
}

# Install the ruby runtime along with any dependencies.
install_runtime_packages() {
  pkgs=("$(ruby_runtime)" "$(condensed_ruby_runtime)-bundler" "nginx")

  # if nodejs is required, let's install it
  if [[ "$(is_nodejs_required)" = "true" ]]; then
    pkgs+=("$(nodejs_dependencies)")
  fi

  # add any client dependencies
  pkgs+=("$(query_dependencies)")

  nos_install ${pkgs[@]}
}

# Uninstall build dependencies
uninstall_build_packages() {
  # currently ruby doesn't install any build-only deps... I think
  pkgs=("$(ruby_runtime)" "$(condensed_ruby_runtime)-bundler" $(query_dependencies) ruby nodejs)

  # if nodejs is required, let's fetch any node build deps
  if [[ "$(is_nodejs_required)" = "true" ]]; then
    pkgs+=("$(nodejs_dependencies)")
  fi

  # if pkgs isn't empty, let's uninstall what we don't need
  if [[ ${#pkgs[@]} -gt 0 ]]; then
    nos_uninstall ${pkgs[@]}
  fi
}

# The bundler package will look something like ruby22-bundler so
# we need to fetch the condensed runtime to use for the package
condensed_ruby_runtime() {
  version=$(ruby_runtime)
  echo "${version//[.-]/}"
}

# set the bundle config to ensure gems are installed into vendor
set_bundle_config() {
  mkdir -p "$(nos_code_dir)/.bundle"
  nos_template_file "bundle/config" "$(nos_code_dir)/.bundle/config"
}

# Install dependencies from Gemfile
bundle_install() {
  if [[ -f $(nos_code_dir)/Gemfile ]]; then

    cd $(nos_code_dir)
    nos_run_process "Running bundle install" \
      "bundle install"
    cd - >/dev/null
  fi
}

# Clean the bundle to remove any unecessary gems
bundle_clean() {
  if [[ -f $(nos_code_dir)/Gemfile ]]; then

    cd $(nos_code_dir)
    nos_run_process "Cleaning bundle" "bundle clean"
    cd - >/dev/null
  fi
}

# compiles a list of dependencies that will need to be installed
query_dependencies() {
  deps=()

  # mysql
  if [[ `cat $(nos_code_dir)/Gemfile | grep 'mysql'` ]]; then
    deps+=(mysql-client)
  fi
  # memcache
  if [[ `cat $(nos_code_dir)/Gemfile | grep 'memcache'` ]]; then
    deps+=(libmemcached)
  fi
  # postgres
  if [[ `cat $(nos_code_dir)/Gemfile | grep 'pg'` ]]; then
    deps+=(postgresql94-client)
  fi

  echo "${deps[@]}"
}

# Generate the payload to render the npm profile template
bundle_profile_payload() {
  cat <<-END
{
  "code_dir": "$(nos_code_dir)"
}
END
}

# ensure node_modules/.bin is persisted to the PATH
persist_bundle_bin_to_path() {
  nos_template \
    "profile.d/bundle.sh" \
    "$(nos_etc_dir)/profile.d/bundle.sh" \
    "$(bundle_profile_payload)"
}

