package App::zimmerman::script;
use strict;
use warnings;
use Carp;
use URI;
use Data::Dumper;
use YAML qw/LoadFile/;
use Pod::Usage;
use File::Basename;
use File::Path;
use File::Spec;
use Pod::Usage;
use App::zimmerman::Command::_base;
use App::zimmerman::Repo::_base;
use ExtUtils::MakeMaker 6.31;

my $RELEASES_DIR    = "releases";
my $CURRENT_LINK    = "current";
my $SITECONF_DIR    = "zim";
my $SITECONF_FILE   = "site.yml";

sub new {
    my ($class, %p) = @_;
    my $self = bless { }, $class;
    foreach my $k (keys %p) {
        $self->{$k} = $p{$k};
    }
    $self->{script_name}    = basename $0;
    $self->{siteconf_dir}   = $SITECONF_DIR;
    $self->{siteconf_file}  = $SITECONF_FILE;
    $self->{releases_dir}   = $RELEASES_DIR;
    $self->{current_link}   = $CURRENT_LINK;
    return $self;
}


sub load_config {
    my ($self, $arga, $argh) = @_;
    if (not exists $self->{rc}) {
        # set default config file
        my $rcdir = File::Spec->catdir($ENV{HOME}, ".".$self->{script_name});
        $self->{rc} = File::Spec->catfile($rcdir, $self->{script_name}."rc");
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
