package RT::ObjectCustomField;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->CustomFieldObj );

    if ($self->ObjectId) {
        my $class = $self->CustomFieldObj->RecordClassFromLookupType;
        my $obj = $class->new( $self->CurrentUser );
        $obj->Load( $self->ObjectId );
        $deps->Add( out => $obj );
    }
}

sub Serialize {
    my $self = shift;
    my %args = (@_);
    my %store = $self->SUPER::Serialize(@_);

    if ($store{ObjectId}) {
        my $class = $self->CustomFieldObj->RecordClassFromLookupType;
        my $obj = $class->new( RT->SystemUser );
        $obj->Load( $store{ObjectId} );
        $store{ObjectId} = \($obj->UID);
    }
    return %store;
}

1;
