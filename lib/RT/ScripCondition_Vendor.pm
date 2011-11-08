package RT::ScripCondition;
use strict;
use warnings;

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    return if $importer->SkipBy( "Name", $class, $uid, $data );

    return 1;
}

1;
