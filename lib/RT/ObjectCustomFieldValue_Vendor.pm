package RT::ObjectCustomFieldValue;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->CustomFieldObj );
    $deps->Add( out => $self->Object );
}

1;
