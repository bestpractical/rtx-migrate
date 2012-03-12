package RT::Attribute;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);
    $deps->Add( out => $self->Object );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    if ($data->{Object} and ref $data->{Object}) {
        my $on_uid = ${ $data->{Object} };
        return if $importer->ShouldSkipTransaction($on_uid);
    }
    return $class->SUPER::PreInflate( $importer, $uid, $data );
}

1;
