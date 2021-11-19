#!/usr/local/bin/zsh

SCAFFOLD_VERSION="0.2.0"

RED="`tput setaf 1`"
GREEN="`tput setaf 2`"
CYAN="`tput setaf 6`"
BOLD="`tput bold`"
NC="`tput sgr0`"

function create_project_dir() {
  echo "Creating new directory ..."

  if mkdir "$1"; then
    echo >$2 "Created dir"
    return 0
  else
    echo >$2 "Cannot create dir"
    return 1
  fi
}

function create_python_venv() {
  echo "${GREEN}Creating and activating new Python venv ...${NC}"
  python -m venv venv
  source 'venv/bin/activate'
}

function log_pkg_version() {
  found_pkg_info=$(pip list | grep -iF "$1")
  # echo "found_pkg_info: $found_pkg_info"
  cleaned_pkg_info=$(echo "$found_pkg_info" | sed -e 's/[[:space:]]\{1,\}/|/g')
  # echo "cleaned_pkg_info: $cleaned_pkg_info"
  pkg_info_parts=("${(@s/|/)cleaned_pkg_info}")
  pkg_info_name="${pkg_info_parts[1]}"
  # echo "pkg_info_name: $pkg_info_name"
  pkg_info_version="${pkg_info_parts[2]}"
  # echo "pkg_info_version: $pkg_info_version"

  echo "${GREEN}Logging $pkg_info_name==$pkg_info_version ...${NC}"
  if [[ "$2" == "dev" ]]; then
    echo "$pkg_info_name==$pkg_info_version" >>"requirements-dev.txt"
  else
    echo "$pkg_info_name==$pkg_info_version" >>"requirements.txt"
  fi

  unset found_pkg_info
  unset cleaned_pkg_info
  unset pkg_info_parts
  unset pkg_info_name
  unset pkg_info_version
}

function install_python_baseline() {
  echo "${GREEN}Installing Python baseline ...${NC}"
  touch requirements.txt
  touch requirements-dev.txt

  pip install --upgrade pip
  # log_pkg_version "pip" "prod"
  log_pkg_version "pip" "dev"

  pip install --upgrade setuptools
  log_pkg_version "setuptools" "dev"

  pip install flake8
  log_pkg_version "flake8" "dev"

  # python -m pip install python-dateutil
  # log_pkg_version "python-dateutil" "prod"
}

function unset_variables() {
  unset project_name
  unset project_type
  unset ask_result
}

function end_on_error() {
  echo "${RED}\nScaffolding ended with an error.${NC}"
  unset_variables
  return 1
}

function end_on_ok() {
  echo "${GREEN}\nScaffolding ended ok. Happy hacking!${NC}"
  unset_variables
  return 0
}

function select_project_type() {
  # List of possible project types
  list=("Python_Basic" "Python_AWS_Serverless")

  select var in $list; do
    if [ x"$var" != x"" ]; then
      echo $var
    fi
  return $var
  done
}

function scaffold_python_basic() {
  echo "${GREEN}Scaffolding Python_Basic with name $2 ...${NC}"
  create_project_dir $2
  retval=$?
  if [[ "$retval" == 0 ]]; then
    echo "${GREEN}Project Directory created succesfully.${NC}"
    cd "$2"
    # Make sure, that we really are in the new project dir,
    # before installing anything.
    if [[ "$(pwd)" == "$1/$2" ]]; then
      echo "Successfully switched to project dir."
      create_python_venv
      install_python_baseline
      cp -r "$HELPERS_HOME/templates/Python_Basic/" .
      return 0
    else
      echo "${RED}Something went wrong while creating or changing to the project dir $2 in $1${NC}"
      return 1
    fi
  else
    echo "${RED}Something went wrong while creating the project dir $2 in $1${NC}"
    return 1
  fi

  return 1
}

function ask_yes_no() {
  # Ask for yes or no, return 'yes' or 'no'
  list=("yes" "no")

  select var in $list; do
    if [ x"$var" != x"" ]; then
      echo $var
    fi
  return $var
  done
}

function init_git() {
  echo "${CYAN}\nInitialize git repository?${NC}"
  ask_result=$(ask_yes_no)
  if [[ "$ask_result" == "yes" ]]; then
    echo "${GREEN}Initializing git repository ...${NC}"
    cp "$HELPERS_HOME/templates/gitignore" ./.gitignore
    git init --initial-branch=main
    git add .
    git commit -m "Initial commit done by scaffolding."
    git status
  fi

  unset ask_result
}

if [[ -v HELPERS_HOME ]]; then
  # echo "${GREEN}HELPERS_HOME is set: $HELPERS_HOME${NC}"
  echo "${GREEN}Start scaffolding (running v$SCAFFOLD_VERSION).\n${NC}"
else
  echo "${RED}Environment variable HELPERS_HOME is not set.${NC}"
  return 1
fi


# Ask for project name
vared -p "${CYAN}Project name? ${NC}" -c project_name
project_name=$(echo "$project_name" | sed -e 's/[^A-Za-z0-9_-]/_/g')
echo "project_name (with allowed naming scheme): $project_name"

# Check, that the name is at least one character long.
if [[ -z "$project_name" ]]; then
  echo "${RED}ERROR: Project name must over 0 characters long.${NC}"
  end_on_error
else
  # Check, if the project dir already exists. If it does, halt the execution.
  if [[ -d "$project_name" ]]; then
    echo "${RED}ERROR: Project directory $project_name already exists. Try with another name.${NC}"
    end_on_error
  else
    echo "Dir $project_name does not exist. Moving to next step ..."

    # Ask for project type
    echo "\n${CYAN}Which kind of project you want to scaffold?${NC}"
    project_type=$(select_project_type)
    echo "project_type: $project_type"

    # Scaffold selected project type with entered name
    if [[ "$project_type" == "Python_Basic" ]]; then
      scaffold_python_basic $(pwd) $project_name
      init_git $(pwd) $project_name
      retvalue=$?
      # echo "RETVAL2: $retvalue"
      if [[ "$retvalue" == 0 ]]; then
        end_on_ok
      else
        end_on_error
      fi
    elif [[ "$project_type" == "Python_AWS_Serverless" ]]; then
      echo "\n${RED}Waiting for implementation.${NC}"
      end_on_error
    fi
  fi
fi
