package App::zimmerman::script;
use strict;
use warnings;
use Carp;
use URI;
use Data::Dumper;
use YAML qw/LoadFile/;
use Pod::Usage ();
use File::Basename ();
use File::Path ();
use File::Spec ();
use Pod::Usage;
use Term::Prompt ();
use App::zimmerman;
use App::zimmerman::Config::Export;
use App::zimmerman::Config::Site;
use App::zimmerman::Config::Release;
use App::zimmerman::Command::_base;
use App::zimmerman::Repo::_base;
use ExtUtils::MakeMaker 6.31;

my $SCRIPTCONF_DIR                  = ".zim";
my $SCRIPTCONF_FILE                 = "zimrc";
my $SCRIPTCONF_CACHED_EXPORTS       = "_cached_exports";
my $SCRIPTCONF_EXPORT_CONFIG_FILE   = "_this_export.yml";

my $SITECONF_DIR                = "zim";
my $SITECONF_FILE               = "site.yml";

my $CURRENT_LINK                = "current";
my $RELEASES_DIR                = "releases";
my $RELEASECONF_DIR             = "zim";
my $RELEASECONF_FILE            = "_this_release.yml";

sub new {
    my ($class, %p) = @_;
    my $self = bless { }, $class;
    foreach my $k (keys %p) {
        $self->{$k} = $p{$k};
    }
    $self->{script_name}            = File::Basename::basename $0;
    $self->{siteconf_dir}           = $SITECONF_DIR;
    $self->{siteconf_file}          = $SITECONF_FILE;
    $self->{releases_dir}           = $RELEASES_DIR;
    $self->{current_link}           = $CURRENT_LINK;
    $self->{releaseconf_dir}        = $RELEASECONF_DIR;
    $self->{releaseconf_file}       = $RELEASECONF_FILE;
    $self->{scriptconf_export_config_file}          = $SCRIPTCONF_EXPORT_CONFIG_FILE;
    $self->{scriptconf_path}                        = File::Spec->catdir($ENV{HOME}, $SCRIPTCONF_DIR);
    $self->{scriptconf_filepath}                    = File::Spec->catdir($ENV{HOME}, $SCRIPTCONF_DIR, $SCRIPTCONF_FILE);
    $self->{scriptconf_cached_exports_path}         = File::Spec->catdir($ENV{HOME}, $SCRIPTCONF_DIR, $SCRIPTCONF_CACHED_EXPORTS);
    return $self;
}


sub load_config {
    my ($self, $arga, $argh) = @_;
    if (not exists $self->{rc}) {
        # set default config file
        $self->{rc} = $self->{scriptconf_filepath};
    }
    eval {
        # configure based on rc
        my $yml = LoadFile($self->{rc});
        foreach my $k (keys %$yml) {
            if (not exists $self->{$k}) {
                # don't overwrite params specified via new()
                $self->{$k} = $yml->{$k};
            }
        }
    };
    if ($@ and exists($self->{rc})) {
        die "Unable to load config file: $@\n\nPlease run setup via: $self->{script_name} configure\n\n";
    }
    return $self;
}


# dispatch
sub dispatch {
    my ($self, $command, $arga, $argh) = @_;
    if (not $command) { die $self->basic_help; }
    my $command_class = 'App::zimmerman::Command::'.$command;
    eval "require $command_class;";
    if ($@) { die "Invalid command '$command_class': $@\n".$self->basic_help; }
    my $c = $command_class->new( script => $self );
    if ($argh->{help}) {
        $c->help;
    }
    $c->run( $arga, $argh );
}


# ================ commons API

sub get_release_config_filepath {
    my ($self, %p) = @_;
    ($p{install_base})
        or croak "install_base required";
    ($p{release_id})
        or croak "release_id required";
    my $path = File::Spec->catdir(
        $p{install_base},
        $self->{releases_dir}, 
        $p{release_id},
        $self->{releaseconf_dir}, 
        $self->{releaseconf_file},
    );
    return $path;
}

sub get_current_release_config {
    my ($self, %p) = @_;
    ($p{install_base})
        or croak "install_base required";
    my $link_path = File::Spec->catdir($p{install_base}, $self->{current_link});
    (-l $link_path)
        or die "Cannot find current release symlink at $link_path";
    my $pointing_to = readlink($link_path);
    my $current_release_path = File::Spec->catdir($p{install_base}, $pointing_to);
    (-d $current_release_path)
        or die "current symlink does not seem to point to a release directory";
    my $c;
    eval {
        my $path = File::Spec->catdir(
            $current_release_path,
            $self->{releaseconf_dir}, 
            $self->{releaseconf_file},
        );
        $c = App::zimmerman::Config::Release->from_file($path);
    };
    if ($@) {
        die "current symlink points to a release directory";
    }
    return $c;
}

sub set_release_symlink {
    my ($self, %p) = @_;
    my $symlink_supported = eval { symlink("",""); 1 };
    ($symlink_supported)
        or die "symbolic links are not supported on this platform";
    ($p{release_id})
        or croak "Invalid release_id";
    ($p{install_base} and -d $p{install_base})
        or croak "Invalid install_base";
    ($p{release_origin})
        or croak "Invalid release_origin";

    my $rollback_id;
    my $current_release_config;
    eval {
        $current_release_config = $self->get_current_release_config(
            install_base            => $p{install_base},
        );
    };
    if ($@) {
        # nop
        # here, it means there is no current release yet (this is the initial release)
    }

    if ($current_release_config) {
        $rollback_id = $current_release_config->{release_id};
    }
    
    # note the latest release_id
    if (defined $rollback_id) {
        ($rollback_id =~ /^\d{14}$/)
            or die "Invalid release ID";
    }

    # current_release refers to the release pointed to by "current" symlink
    # this_release refers to this release we want "current" symlink to be repointed

    my $this_release_config_filepath = $self->get_release_config_filepath(
        install_base        => $p{install_base},
        release_id          => $p{release_id},
    );
    my $this_release_config;
    if (-e $this_release_config_filepath) {
        $this_release_config = App::zimmerman::Config::Release->from_file( $this_release_config_filepath );
    }
    else {
        $this_release_config = App::zimmerman::Config::Release->new;
        $this_release_config->set_file_name( $this_release_config_filepath );
    }
    $this_release_config->{release_id}              = $p{release_id};
    $this_release_config->{release_origin}          = $p{release_origin};
    $this_release_config->{rollback_id}             = $rollback_id;
    $this_release_config->save();

    # TODO:
    # set the rollforward_id

    # here, we attempt to delete the current symlink so that we can repoint it to this_release
    my $current_link_path = File::Spec->catdir($p{install_base}, $self->{current_link});
    if (-l $current_link_path) {
        unlink $current_link_path
            or die "Existing current link ($current_link_path) cannot be deleted";
    }
        
    # point the link (relative link), via a child process
    my $link_dest_rel = File::Spec->catdir($self->{releases_dir}, $p{release_id});
    my $link_dest = File::Spec->catdir($p{install_base}, $self->{releases_dir}, $p{release_id});
    (-d $link_dest and -x $link_dest)
        or die "symlink destination directory is invalid ($link_dest)";

    my $pid = fork;
    (defined $pid)
        or die "fork is not supported on this platform";
    if ($pid == 0) {
        chdir $p{install_base}
            or die "Unable to change directory to $p{install_base}";
        symlink( $link_dest_rel, $self->{current_link} )
            or die "Failed symlink() call";
        exit(0);
    }
    else {
        waitpid $pid, 0;
        my $code = $?;
        if ($code != 0) {
            die "Unable to symlink ($current_link_path) to ($link_dest)";
        }
    }
}


# ================ helper

sub get_repo_backend { 
    my ($self, %p) = @_;
    my $url = $p{url};
    # FIXME: can be refactored into a factory later
    # guess the backend 
    my $scheme = URI->new($url)->scheme;
    my $repo_backend = uc($scheme || 'FS');
    if ($repo_backend eq 'file') { $repo_backend = 'FS'; }
    # load class
    my $backend_class = 'App::zimmerman::Repo::'.$repo_backend;
    eval "require $backend_class;";
    if ($@) {
        die "Unable to load backend for [$url]: $@";
    }
    my $repo = $backend_class->new( script => $self, url => $url );
#    if (not exists $self->{scm_client}) {
#        my $client = qx{which svn}; chomp $client; # default to svn
#        $self->{scm_client} = $client;
#    }
#    (File::Spec->file_name_is_absolute($self->{scm_client}) and -x $self->{scm_client})
#        or die "Unable to find a suitable scm client";
    return $repo;
}


sub get_release_origin_string {
    my ($self, $site_name, $site_branch) = @_;
    return join(';', "site=$site_name", "site_branch=$site_branch");
}



sub _get_site_scm_url {
    my ($self, $site_name, $branch) = @_;
    # NOTE: assumes a certain layout: scmscheme://host/reporoot/{{site}}/{{branch}}
    return join("/", # force slash for now, TODO: we can probably use URI here
        $self->{scm_repository_root},
        $site_name,
        $branch || '',
    );
}


sub _exec_scm_command {
    my ($self, @params) = @_;
    my @cmds = (
        $self->{scm_client},
        @params,
        '2>', File::Spec->devnull,
    );
    my $cmd = join(' ', @cmds);
    open my $fh, "$cmd |"
        or die $!;
    my @out = <$fh>
        or die $!;
    chomp @out;
    return @out;
}


sub is_valid_install_base {
    my ($self, $install_base) = @_;
    return (-d $install_base and -w $install_base);
}



# ================ help


sub usage {
    my ($self, $command) = @_;
    $command ||= 'command';
    return "Usage: $self->{script_name} $command [options] [...]";
}

sub basic_help {
    my ($self) = @_;
    return <<EOF;
Usage: $self->{script_name} command [options] [...]

Try `$self->{script_name} help` for more options.
EOF
}

sub chat {
    my ($self, $msg) = @_;
    print STDERR $msg;
}


1;

__END__
