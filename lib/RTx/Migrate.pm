use strict;
use warnings;
package RTx::Migrate;

our $VERSION = '0.12';

=head1 NAME

RTx-Migrate - Serialize and import entire RT databases

=head1 INSTALLATION 

=over

=item perl Makefile.PL

=item make

=item make install

May need root permissions

=item Edit your /opt/rt4/etc/RT_SiteConfig.pm

Add this line:

    Set(@Plugins, qw(RTx::Migrate));

or add C<RTx::Migrate> to your existing C<@Plugins> line.

=item Patch RT

If you are running RT 4.0.4 or lower, you will need to apply the provided
'rt.patch' file.  This is done via:

    (cd /opt/rt4; patch -p1) < rt.patch

If you are running RT 4.0.5, you need to apply the provided 'rt-4.0.5.patch'
file.  This is done via:

    (cd /opt/rt4; patch -p1) < rt-4.0.5.patch

=item Export your database

    /opt/rt4/local/plugins/RTx-Migrate/sbin/rt-serializer

This will output a directory named after your $Organization, and today's
date.

=item Import into an existing RT database

You will need to tun all of the above steps to install the plugin on the
server which the data is to be imported.  You should then transfer over
the directory created in the previous step.

    /opt/rt4/local/plugins/RTx-Migrate/sbin/rt-importer directory:name/ \
        --originalid 'Original ticket ID'

The --originalid flag is used to provide the name of the CF to use (and
create, if necessary) to store the previous ticket ID that each ticket
had.

=back

=head1 AUTHOR

Alex Vandiver <alexmv@bestpractical.com>

=head1 BUGS

All bugs should be reported via
L<http://rt.cpan.org/Public/Dist/Display.html?Name=RTx-Migrate>
or L<bug-RTx-Migrate@rt.cpan.org>.


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2011 by Best Practical Solutions, LLC

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

{ my %word = (
    a     => -4,
    alpha => -4,
    b     => -3,
    beta  => -3,
    pre   => -2,
    rc    => -1,
    head  => 9999,
);
sub cmp_version($$) {
    my ($a, $b) = (@_);
    my @a = grep defined, map { /^[0-9]+$/? $_ : /^[a-zA-Z]+$/? $word{$_}|| -10 : undef }
        split /([^0-9]+)/, $a;
    my @b = grep defined, map { /^[0-9]+$/? $_ : /^[a-zA-Z]+$/? $word{$_}|| -10 : undef }
        split /([^0-9]+)/, $b;
    @a > @b
        ? push @b, (0) x (@a-@b)
        : push @a, (0) x (@b-@a);
    for ( my $i = 0; $i < @a; $i++ ) {
        return $a[$i] <=> $b[$i] if $a[$i] <=> $b[$i];
    }
    return 0;
}}

1;
