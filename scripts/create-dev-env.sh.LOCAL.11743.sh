#!/usr/bin/env bash

#Exit if any commands return a non-zero status
set -e

# posix compliant sanity check
if [ -z $BASH ] || [  $BASH = "/bin/sh" ]; then
    echo "Please use the bash interpreter to run this script"
    exit 1
fi

trap "ouch" ERR

ouch() {
    printf '\E[31m'

    cat<<EOL

    !! ERROR !!

    The last command did not complete successfully,
    For more details or trying running the
    script again with the -v flag.

    Output of the script is recorded in $LOG

EOL
    printf '\E[0m'

}

#Setting error color to red before reset
error() {
      printf '\E[31m'; echo "$@"; printf '\E[0m'
}

#Setting warning color to magenta before reset
warning() {
      printf '\E[35m'; echo "$@"; printf '\E[0m'
}

#Setting output color to cyan before reset
output() {
      printf '\E[36m'; echo "$@"; printf '\E[0m'
}

usage() {
    cat<<EO

    Usage: $PROG [-c] [-v] [-h]

            -c        compile scipy and numpy
            -s        give access to global site-packages for virtualenv
            -v        set -x + spew
            -h        this

EO
    info
}

info() {
    cat<<EO
    edX base dir : $BASE
    Python virtualenv dir : $PYTHON_DIR
    Ruby RVM dir : $RUBY_DIR
    Ruby ver : $RUBY_VER

EO
}

change_git_push_defaults() {

    #Set git push defaults to upstream rather than master
    output "Changing git defaults"
    git config --global push.default upstream

}

# clone_repos() {
#
#     change_git_push_defaults
#
#     cd "$BASE"
#
#     if [[ -d "$BASE/edx-platform/.git" ]]; then
#         output "Pulling edx platform"
#         cd "$BASE/edx-platform"
#         git pull
#     else
#         output "Cloning edx platform"
#         if [[ -d "$BASE/edx-platform" ]]; then
#             output "Creating backup for existing edx platform"
#             mv "$BASE/edx-platform" "${BASE}/edx-platform.bak.$$"
#         fi
#         git clone https://github.com/edx/edx-platform.git
#     fi
# }


### START

PROG=${0##*/}

# Adjust this to wherever you'd like to place the codebase
BASE="${PROJECT_HOME:-$HOME}/edx_all"

# Use a sensible default (~/.virtualenvs) for your Python virtualenvs
# unless you've already got one set up with virtualenvwrapper.
PYTHON_DIR=${WORKON_HOME:-"$HOME/.virtualenvs"}

# RVM defaults its install to ~/.rvm, but use the overridden rvm_path
# if that's what's preferred.
RUBY_DIR=${rvm_path:-"$HOME/.rvm"}

LOG="/var/tmp/install-$(date +%Y%m%d-%H%M%S).log"

# Make sure the user's not about to do anything dumb
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run using sudo or as the root user"
    usage
    exit 1
fi

# If in an existing virtualenv, bail
if [[ "x$VIRTUAL_ENV" != "x" ]]; then
    envname=`basename $VIRTUAL_ENV`
    error "Looks like you're already in the \"$envname\" virtual env."
    error "Run \`deactivate\` and then re-run this script."
    usage
    exit 1
fi

# Read arguments
ARGS=$(getopt "cvhs" "$*")
if [[ $? != 0 ]]; then
    usage
    exit 1
fi
eval set -- "$ARGS"
while true; do
    case $1 in
        -c)
            compile=true
            shift
            ;;
        -s)
            systempkgs=true
            shift
            ;;
        -v)
            set -x
            verbose=true
            shift
            ;;
        -h)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
    esac
done

cat<<EO

  This script will setup a local edX environment, this
  includes

       * Django
       * A local copy of Python and library dependencies
       * A local copy of Ruby and library dependencies

  It will also attempt to install operating system dependencies
  with apt(debian) or brew(OSx).

  To compile scipy and numpy from source use the -c option

  !!! Do not run this script from an existing virtualenv !!!

  If you are in a ruby/python virtualenv please start a new
  shell.

EO
info
output "Press return to begin or control-C to abort"
read dummy


# Log all stdout and stderr

exec > >(tee $LOG)
exec 2>&1


# Install basic system requirements

mkdir -p $BASE
case `uname -s` in
    [Ll]inux)
        command -v lsb_release &>/dev/null || {
            error "Please install lsb-release."
            exit 1
        }

        distro=`lsb_release -cs`
        case $distro in
            wheezy|jessie|maya|olivia|nadia|precise|quantal)
                warning "
                        Debian support is not fully debugged. Assuming you have standard
                        development packages already working like scipy rvm, the
                        installation should go fine, but this is still a work in progress.

                        Please report issues you have and let us know if you are able to figure
                        out any workarounds or solutions

                        Press return to continue or control-C to abort"

                read dummy
                sudo apt-get install git ;;
            squeeze|lisa|katya|oneiric|natty|raring)
                warning "
                          It seems like you're using $distro which has been deprecated.
                          While we don't technically support this release, the install
                          script will probably still work.

                          Raring requires an install of rvm to work correctly as the raring
                          package manager does not yet include a package for rvm

                          Press return to continue or control-C to abort"
                read dummy
                sudo apt-get install git
                ;;

            *)
                error "Unsupported distribution - $distro"
                exit 1
               ;;
        esac
        ;;

    Darwin)
        if [[ ! -w /usr/local ]]; then
            cat<<EO

        You need to be able to write to /usr/local for
        the installation of brew and brew packages.

        Either make sure the group you are in (most likely 'staff')
        can write to that directory or simply execute the following
        and re-run the script:

        $ sudo chown -R $USER /usr/local
EO

            exit 1

        fi

        command -v brew &>/dev/null || {
            output "Installing brew"
            /usr/bin/ruby <(curl -fsSkL raw.github.com/mxcl/homebrew/go)
        }
        command -v git &>/dev/null || {
            output "Installing git"
            brew install git
        }

        ;;
    *)
        error "Unsupported platform. Try switching to either Mac or a Debian-based linux distribution (Ubuntu, Debian, or Mint)"
        exit 1
        ;;
esac


# Clone MITx repositories

#clone_repos

# Sanity check to make sure the repo layout hasn't changed
if [[ -d $BASE/edx-platform/scripts ]]; then
    output "Installing system-level dependencies"
    bash $BASE/edx-platform/scripts/install-system-req.sh
else
    error "It appears that our directory structure has changed and somebody failed to update this script.
            raise an issue on Github and someone should fix it."
    exit 1
fi

# Install system-level dependencies



# Ensure we have RVM available as a shell function so that it can mess
# with the environment and set everything up properly. The RVM install
# process adds this line to login scripts, so this shouldn't be necessary
# for the user to do each time.
if [[ `type -t rvm` != "function" ]]; then
  source $RUBY_DIR/scripts/rvm
fi

# Ruby doesn't like to build with clang, which is the default on OS X, so
# use gcc instead. This may not work, since if your gcc was installed with
# XCode 4.2 or greater, you have an LLVM-based gcc, which also doesn't
# always play nicely with Ruby, though it seems to be better than clang.
# You may have to install apple-gcc42 using Homebrew if this doesn't work.
# See `rvm requirements` for more information.
case `uname -s` in
    Darwin)
        export CC=gcc
        ;;
esac

# Let the repo override the version of Ruby to install
#if [[ -r $BASE/edx-platform/.ruby-version ]]; then
#  RUBY_VER=`cat $BASE/edx-platform/.ruby-version`
#fi

# Current stable version of RVM (1.19.0) requires the following to build Ruby:
#
# autoconf automake libtool pkg-config libyaml libxml2 libxslt libksba openssl
#
# If we decide to upgrade from the current version (1.15.7), can run
#
# LESS="-E" rvm install $RUBY_VER --autolibs=3 --with-readline
#
# to have RVM look for a package manager like Homebrew and install any missing
# libs automatically. RVM's --autolibs flag defaults to 2, which will fail if
# any required libs are missing.
#LESS="-E" rvm install $RUBY_VER --with-readline

##----roshan
#sudo apt-get remove --purge ruby-rvm ruby
#sudo rm -rf /usr/share/ruby-rvm /etc/rmvrc /etc/profile.d/rvm.sh
#rm -rf ~/.rvm* ~/.gem/ ~/.bundle*

sudo apt-get install -y \
git \
build-essential \
curl \
wget

echo "[[ -s '${HOME}/.rvm/scripts/rvm' ]] && source '${HOME}/.rvm/scripts/rvm'" >> ~/.bashrc
curl -L https://get.rvm.io | bash -s stable
# Create the "edx" gemset
rvm install 1.9.3-p374
rvm use --default 1.9.3-p374
source $HOME/.rvm/scripts/rvm
#rvm use "$RUBY_VER@edx-platform" --create
#rvm rubygems latest

output "Installing gem bundler"
gem install bundler

output "Installing ruby packages"
bundle install --gemfile $BASE/edx-platform/Gemfile


#Install Python virtualenv

output "Installing python virtualenv"

case `uname -s` in
    Darwin)
        # Add brew's path
        PATH=/usr/local/share/python:/usr/local/bin:$PATH
        ;;
esac

# virtualenvwrapper uses the $WORKON_HOME env var to determine where to place
# virtualenv directories. Make sure it matches the selected $PYTHON_DIR.
export WORKON_HOME=$PYTHON_DIR


# Load in the mkvirtualenv function if needed
if [[ `type -t mkvirtualenv` != "function" ]]; then
case `uname -s` in
        Darwin)
            source $(which virtualenvwrapper.sh)
        ;;

        Linux)
# later, can add an `lsb_release -cs` test, if desired:
            # |squeeze|wheezy|jessie|maya|lisa|olivia|nadia|natty|oneiric|precise|quantal|raring)
            command -v virtualenvwrapper.sh &>/dev/null && {
                source $(which virtualenvwrapper.sh)
            } || {
                # this will be an older one; newer ones are installed
                # in /usr/local/bin/virtualenvwrapper.sh
                if [[ -f "/etc/bash_completion.d/virtualenvwrapper" ]]; then
source /etc/bash_completion.d/virtualenvwrapper
                else
error "Could not find virtualenvwrapper"
                    exit 1
                fi
            }
        ;;
    esac
fi

# Create edX virtualenv and link it to repo
# virtualenvwrapper automatically sources the activation script
if [[ $systempkgs ]]; then
mkvirtualenv -a "$WORKON_HOME" --system-site-packages edx-platform || {
      error "mkvirtualenv exited with a non-zero error"
      return 1
    }
else
    # default behavior for virtualenv>1.7 is
    # --no-site-packages
    mkvirtualenv -a "$WORKON_HOME" edx-platform || {
      error "mkvirtualenv exited with a non-zero error"
      return 1
    }
fi


# compile numpy and scipy if requested

NUMPY_VER="1.6.2"
SCIPY_VER="0.10.1"

if [[ -n $compile ]]; then
output "Downloading numpy and scipy"
    curl -sL -o numpy.tar.gz http://downloads.sourceforge.net/project/numpy/NumPy/${NUMPY_VER}/numpy-${NUMPY_VER}.tar.gz
    curl -sL -o scipy.tar.gz http://downloads.sourceforge.net/project/scipy/scipy/${SCIPY_VER}/scipy-${SCIPY_VER}.tar.gz
    tar xf numpy.tar.gz
    tar xf scipy.tar.gz
    rm -f numpy.tar.gz scipy.tar.gz
    output "Compiling numpy"
    cd "$BASE/numpy-${NUMPY_VER}"
    python setup.py install
    output "Compiling scipy"
    cd "$BASE/scipy-${SCIPY_VER}"
    python setup.py install
    cd "$BASE"
    rm -rf numpy-${NUMPY_VER} scipy-${SCIPY_VER}
fi

# building correct version of distribute from source
DISTRIBUTE_VER="0.6.28"
output "Building Distribute"
SITE_PACKAGES="$WORKON_HOME/edx-platform/lib/python2.7/site-packages"
cd "$SITE_PACKAGES"
curl -O http://pypi.python.org/packages/source/d/distribute/distribute-${DISTRIBUTE_VER}.tar.gz
tar -xzvf distribute-${DISTRIBUTE_VER}.tar.gz
cd distribute-${DISTRIBUTE_VER}
python setup.py install
cd ..
rm distribute-${DISTRIBUTE_VER}.tar.gz

DISTRIBUTE_VERSION=`pip freeze | grep distribute`

if [[ "$DISTRIBUTE_VERSION" == "distribute==0.6.28" ]]; then
output "Distribute successfully installed"
else
error "Distribute failed to build correctly. This script requires a working version of Distribute 0.6.28 in your virtualenv's python installation"
  exit 1
fi

case `uname -s` in
    Darwin)
        # on mac os x get the latest distribute and pip
        pip install -U pip
        # need latest pytz before compiling numpy and scipy
        pip install -U pytz
        pip install numpy
        # scipy needs cython
        pip install cython
        # fixes problem with scipy on 10.8
        pip install -e git+https://github.com/scipy/scipy#egg=scipy-dev
        ;;
esac

output "Installing edX pre-requirements"
pip install -r $BASE/edx-platform/requirements/edx/pre.txt

output "Installing edX requirements"
# Install prereqs
cd $BASE/edx-platform
rvm use $RUBY_VER
rake install_prereqs

# Final dependecy
output "Finishing Touches"
cd $BASE
pip install argcomplete
cd $BASE/edx-platform
gem install bundler
bundle install

mkdir -p "$BASE/log" || true
mkdir -p "$BASE/db" || true
mkdir -p "$BASE/data" || true


# Configure Git

output "Fixing your git default settings"
git config --global push.default current

### DONE

cat<<END
   Success!!

   To start using Django you will need to activate the local Python
   and Ruby environments. Ensure the following lines are added to your
   login script, and source your login script if needed:

        source `which virtualenvwrapper.sh`
        source $RUBY_DIR/scripts/rvm

   Then, every time you're ready to work on the project, just run

        $ workon mitx

   To initialize Django

        $ rake django-admin[syncdb]
        $ rake django-admin[migrate]
        $ rake django-admin[update-templates]

   To start the Django on port 8000

        $ rake lms[cms.dev]
        $ rake cms

   Or to start Django on a different <port#>

        $ rake django-admin[runserver,lms,cms.dev,<port#>]
        $ rake django-admin[runserver,cms,cms.dev,<port#>]

  If the  Django development server starts properly you
  should see:

      Development server is running at http://127.0.0.1:<port#>/
      Quit the server with CONTROL-C.

  Connect your browser to http://127.0.0.1:<port#> to
  view the Django site.


END
exit 0