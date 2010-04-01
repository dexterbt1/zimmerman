package App::zimmerman::Command::deploy;
use strict;
use warnings;
use Carp;
use File::Copy;
use File::Spec;
use File::Path;
use File::Basename;
use File::Copy::Recursive;
use POSIX qw/strftime/;
use YAML;
use base qw/App::zimmerman::Command::_base/;


sub run {
    my ($self, $arga, $argh) = @_;

    # load backend repo
    my $repo_url = $argh->{repo} || $self->script->{repo} || '';
    ($repo_url)
        or $self->help("! ERROR: please specify a repository via --repo");
    my $repo = $self->script->get_repo_backend( url => $repo_url );

    my $site_name   = $argh->{site} || $self->script->{site} || '';
    my $site_branch = $argh->{site_branch} || $self->script->{site_branch} || '';
    ($site_name)
        or $self->help("! ERROR: please specify a site name");

    # verify install_base (destination)
    my $install_base = $argh->{install_base} || $self->script->{install_base} || '';
    ($self->script->is_valid_install_base($install_base))
        or $self->help("! ERROR: install_base='$install_base' is not a valid writeable directory");

    $self->script->chat("# ". ("-" x 60) . "\n");
    $self->script->chat("Using repo:            $repo_url\n");
    $self->script->chat("Using site:            $site_name\n");
    if ($site_branch) {
        $self->script->chat("Using site_branch:     $site_branch\n");
    }
    $self->script->chat("Using install_base:    $install_base\n");
    $self->script->chat("# ". ("-" x 60) . "\n");
    

    # we need to generate a auto release_id in the pattern YYYYMMDDHHMMSS
    # this will be used 
    my $release_id = $self->get_auto_release_id();
    my $tmp_base = File::Spec->catdir($install_base, '_tmp', $release_id);
    if (not -e $tmp_base) {
        mkpath $tmp_base;
        $self->{_build_errors} = 0;
        $self->{_tmp_base_created} = 1;
        $self->{_tmp_base} = $tmp_base;
    }

    my $seen_deps = { };
    $seen_deps->{$site_name} = $site_branch;
    $self->start_site_deploy( 
        repo                => $repo,
        release_id          => $release_id,
        site                => $site_name,
        site_branch         => $site_branch,
        install_base        => $install_base,
        install_base_tmp    => $tmp_base,
        seen_deps           => $seen_deps,
    );

    $self->script->chat("# ". ("-" x 60) . "\n");
    $self->script->chat("Updating release symlink ... ");
    eval {
        $self->script->set_release_symlink(
            release_id          => $release_id,
            install_base        => $install_base,
            install_base_tmp    => $tmp_base,
        );
    };
    if ($@) {
        $self->script->chat("FAIL\n");
        die "! Error updating symlink: $@";
    }
    # ... no errors so far
    $self->script->chat("OK\n");
    sleep 1;
}



sub start_site_deploy {
    my ($self, %p) = @_;
    my $repo = $p{repo}
        or croak "Uninitialized 'repo' backend";
    my $siteconf;
    eval {
        my $siteconf_contents = $repo->read_file(
            site        => $p{site},
            site_branch => $p{site_branch},
            file_path   => File::Spec->catfile($self->script->{siteconf_dir}, $self->script->{siteconf_file}),
        );
        $siteconf = App::zimmerman::Config::Site->from_string( $siteconf_contents );
    };
    if ($@) { die "! ERROR: $@"; }

    # install dependencies
    foreach my $df ($siteconf->dependencies) {
        my ($dep_type, $dep_info) = @$df;
        SWITCH: {
            ($dep_type eq 'zim') and do {
                my $dep_site = $dep_info->{site};
                my $dep_site_branch = $dep_info->{site_branch};
                last SWITCH;
            };
            die "Unknown type of dependencies encountered: ".Dump($dep_type, $dep_info);
            last SWITCH;
        }
    }

    # setup paths
    my $site_build_path = File::Spec->catdir( 
        $p{install_base_tmp},
        $self->script->{siteconf_dir},
        "_sources", 
        $p{site}
    );
    my $cache_export_path = File::Spec->catdir(
        $self->script->{scriptconf_cached_exports_path},
        $p{site},
        $p{site_branch} || '_default',
    );
    my $cache_export_config_filepath = File::Spec->catfile(
        $cache_export_path,
        $self->script->{scriptconf_export_config_file},
    );

    # compare cached revision to the current site branch revision
    my $use_cached_copy = 0; # assume cache is stale
    my $cached_site_rev;
    eval {
        my $xconf = App::zimmerman::Config::Export->from_file($cache_export_config_filepath);
        $cached_site_rev = $xconf->{revision};
    };
    if (defined $cached_site_rev) {
        my $current_site_rev = $repo->peek_site_revision(
            site                => $p{site},
            site_branch         => $p{site_branch},
        );
        if (defined($current_site_rev) and ($cached_site_rev eq $current_site_rev)) {
            $use_cached_copy = 1;
        }
    }

    # export, whether from cache or new copy
    my $site_url = $repo->get_url($p{site}, $p{site_branch});
    my $site_branch_info = $p{site_branch} ? sprintf("site_branch=[%s] ",$p{site_branch}) : '';

    if (not $use_cached_copy) {
        $self->script->chat("Exporting fresh copy of site=[$p{site}] ${site_branch_info}from $site_url ... ");
        # we are unable to utilize the cache,
        # we need a fresh export from repository
        if (-e $cache_export_path) {
            rmtree $cache_export_path; # TODO: assumes this succeeds always
        }
        my $revision = $repo->export_site( 
            site                => $p{site},
            site_branch         => $p{site_branch},
            export_to           => $cache_export_path,
        );
        my $exportconfig_file = App::zimmerman::Config::Export->new;
        $exportconfig_file->{revision} = $revision;
        $exportconfig_file->save( $cache_export_config_filepath );
    }
    else {
        $self->script->chat("Reusing previously CACHED export of site=[$p{site}] ${site_branch_info}... ");
    }

    # from here assume export was successful
    File::Copy::Recursive::rcopy( $cache_export_path, $site_build_path )
        or die "Failed export copy from [$cache_export_path] to [$site_build_path]";
    $self->script->chat("OK\n");


    $self->build_test_install(
        site                => $p{site},
        release_id          => $p{release_id},
        site_build_path     => $site_build_path,
        install_base        => $p{install_base},
        install_base_tmp    => $p{install_base_tmp},
    );

} # start_site_deploy



sub build_test_install {
    my ($self, %p) = @_;
    my $build_path = $p{site_build_path} || '';
    my $home = $p{install_base_tmp} || '';
    # double check dirs just to be sure
    (-d $build_path && -w $build_path)
        or croak "non-existent site_build_path";
    (-d $home && -w $home)
        or croak "non-existent install_base_tmp";

    my $env_bin     = qx{which env}; chomp $env_bin;
    ($env_bin)
        or die "'env' command is unavailable in this system";

    # build steps
    my $build_errors = 0;
    my $build_logfile = File::Spec->catfile($ENV{HOME},'.'.$self->script->{script_name},"latest-deploy.log");
    if (-e $build_logfile) {
        unlink $build_logfile;
    }
    foreach my $build_step (qw/configure build test install clean/) {
        my $script_rel = File::Spec->catfile(
            $self->script->{siteconf_dir},
            'build',
            $build_step,
        );
        my $script = File::Spec->catfile(
            $build_path, 
            $self->script->{siteconf_dir},
            'build',
            $build_step,
        );
        # run step script
        $self->script->chat("Building site [".$p{site}."] step=$build_step ... ");
        if (-e $script) {
            #local $SIG{CHLD} = sub { die "Error running build"; }
            #local $SIG{CHLD} = 'IGNORE';
            my $pid = fork;
            (defined $pid) 
                or die "fork call is not supported on this platform";
            if ($pid == 0) {
                chdir $build_path
                    or die "Unable to change directory to build_dir ($build_path)";
                open STDERR, ">>$build_logfile"
                    or die "Unable to redirect STDERR to build log ($build_logfile)";
                open STDOUT, ">>$build_logfile"
                    or die "Unable to redirect STDOUT to build log ($build_logfile)";
                    
                my @env_vars = (
                    'HOME='.$home,
                );
                my @cmd = (
                    $env_bin,
                    @env_vars,
                    $script_rel,
                );
                my $b = join(' ',@cmd);
                exec $b;
                die "Unable to execute build step script ($b)";
            }
            else {
                my $pid = waitpid $pid, 0;
                my $code = $?;
                if ($code != 0) {
                    $build_errors++;
                    $self->script->chat("FAIL\n");
                    last;
                }
            }
            $self->script->chat("OK\n");
        }
        else {
            $self->script->chat("N/A\n");
        }
    } # for

    $self->{_build_errors} = $build_errors;
    (not $build_errors)
        or die "\n! Deploy build process failed. For details, please consult $build_logfile\n\n";

    # move the release
    my $src         = $p{install_base_tmp};
    my $dest_dir    = File::Spec->catdir($p{install_base}, $self->script->{releases_dir});
    if (-e $dest_dir and not(-d $dest_dir)) {
        die "releases directory at ($dest_dir) is not a directory";
    }
    if (not -e $dest_dir) {
        mkpath $dest_dir;
    }
    my $dest = File::Spec->catdir($dest_dir, $p{release_id});
    File::Copy::move( $src, $dest)
        or die "unable to move tmp releases from $src to $dest: $!";
}



# ===============================


sub get_auto_release_id {
    my ($self) = @_;
    return strftime("%Y%m%d%H%M%S",localtime);
}


sub help {
    my ($self, $message) = @_;
    my $u = $self->script->usage('deploy');
    if (defined $message) {
        $u = join("\n",$message,'',$u);
    }
    $self->pod_help(__FILE__, "$u\n");
}


sub DESTROY {
    my ($self) = @_;
    #if ($self->{_tmp_base_created} and not($self->{_build_errors})) {
    if ($self->{_tmp_base_created}) {
        if (-e $self->{_tmp_base}) {
            rmtree $self->{_tmp_base};
        }
    }
}


1;

__END__

=head1 NAME

deploy - build, test and install the site releases

=head1 OPTIONS

=over 4

=item --repo

The root repository URI that contains the site repositories. 

*REQUIRED. Run C<configure> to persist this setting.

=item --install_base

The base path to where deployed sites will be anchored.
Each deploy will create a new directory under C<$install_base/releases/xxxxxxx>.
A symlink C<$install_base/current> will always point to the
last deployed release.

*REQUIRED. Run C<configure> to persist this setting.

=item --site

The site name. Resolved in the repository as C<$repo/$site_name>.
Should be a basename string and not a path. See --site_branch for branching support.

*REQUIRED. Run C<configure> to persist this setting.

=item --site_branch

Site branch. When given, repository is resolved as C<$repo/$site_name/$site_branch>.

*OPTIONAL. Run C<configure> to persist this setting.

=back

=cut
