package App::zimmerman::Command::deploy;
use strict;
use warnings;
use Carp;
use File::Copy;
use File::Spec;
use File::Path;
use File::Basename;
use POSIX qw/strftime/;
use base qw/App::zimmerman::Command::_base/;


sub run {
    my ($self, $arga, $argh) = @_;
    my $repo_url = $argh->{repo} || $self->script->{repo} || '';
    ($repo_url)
        or $self->help("! ERROR: please specify a repository via --repo");
    my $repo = $self->script->get_repo_backend( url => $repo_url );
    my $site_name   = $argh->{site} || $self->script->{site} || '';
    my $site_branch = $argh->{site_branch} || $self->script->{site_branch} || '';
    ($site_name)
        or $self->help("! ERROR: please specify a site name");
    ($site_branch)
        or $self->help("! ERROR: please specify a site_branch");
    # verify install_base (destination)
    my $install_base = $argh->{install_base} || $self->script->{install_base} || '';
    ($self->script->is_valid_install_base($install_base))
        or $self->help("! ERROR: install_base='$install_base' is not a valid writeable directory");

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
        $siteconf = $repo->load_siteconf(
            site                => $p{site},
            site_branch         => $p{site_branch},
            siteconf_path       => File::Spec->catfile($self->script->{siteconf_dir}, $self->script->{siteconf_file}),
        );
    };
    if ($@) { $self->help("! ERROR: $@"); }
    my $site_url = $repo->get_url($p{site}, $p{site_branch});
    $self->script->chat("Exporting site [$p{site}] from $site_url ... ");
    my $site_build_dir = $repo->export_site( 
        site                => $p{site},
        site_branch         => $p{site_branch},
        siteconf_dir        => $self->script->{siteconf_dir},
        export_to           => $p{install_base_tmp},
    );
    $self->script->chat("OK\n");
    $self->build_test_install(
        site                => $p{site},
        release_id          => $p{release_id},
        site_build_dir      => $site_build_dir,
        install_base        => $p{install_base},
        install_base_tmp    => $p{install_base_tmp},
    );

=pod
    $self->install_deps( ... ) # recursive
    $self->build_test_install( ... )

=cut
}


sub build_test_install {
    my ($self, %p) = @_;
    my $build_dir = $p{site_build_dir} || '';
    my $home = $p{install_base_tmp} || '';
    # double check dirs just to be sure
    (-d $build_dir && -w $build_dir)
        or croak "non-existent site_build_dir";
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
            $build_dir, 
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
                chdir $build_dir
                    or die "Unable to change directory to build_dir ($build_dir)";
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

=item --site

The site name. Resolved in the repository as C<$repo/$site_name>.
Should be a basename string and not a path. See --site_branch for branching support.

*REQUIRED. Run C<configure> to persist this setting.

=item --site_branch

Site branch. When given, repository is resolved as C<$repo/$site_name/$site_branch>.

*REQUIRED. Run C<configure> to persist this setting.

=item --install_base

The base path to where deployed sites will be anchored.
Each deploy will create a new directory under C<$install_base/releases/xxxxxxx>.
A symlink C<$install_base/current> will always point to the
last deployed release.

*REQUIRED. Run C<configure> to persist this setting.

=back

=cut
