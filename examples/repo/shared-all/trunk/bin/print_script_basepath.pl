#!/usr/bin/perl
use strict;
use File::Basename ();
use File::Spec();
print File::Spec->rel2abs(File::Basename::dirname($0)),"\n";
__END__
