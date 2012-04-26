package RT::ScripCondition;
use strict;
use warnings;

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    return 1 if $importer->{Clone};

    return not $importer->SkipBy( "Name", $class, $uid, $data );
}

1;
