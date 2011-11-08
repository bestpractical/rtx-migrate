package RT::ACE;
use strict;
use warnings;

sub Dependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::Dependencies($walker, $deps);

    $deps->Add( out => $self->PrincipalObj->Object );
    $deps->Add( out => $self->Object );
}

1;
