package RT::CustomFieldValue;
use strict;
use warnings;

sub Dependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::Dependencies($walker, $deps);

    $deps->Add( out => $self->CustomFieldObj );
}

1;
