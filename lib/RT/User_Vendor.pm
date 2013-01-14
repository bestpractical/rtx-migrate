package RT::User;
use strict;
use warnings;

sub UID {
    my $self = shift;
    return undef unless defined $self->Name;
    return "@{[ref $self]}-@{[$self->Name]}";
}

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    # ACL equivalence group
    my $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'ACLEquivalence' );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    $deps->Add( in => $objs );

    # Memberships in SystemInternal groups
    $objs = RT::GroupMembers->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'MemberId', VALUE => $self->Id );
    my $principals = $objs->Join(
        ALIAS1 => 'main',
        FIELD1 => 'GroupId',
        TABLE2 => 'Principals',
        FIELD2 => 'id',
    );
    my $groups = $objs->Join(
        ALIAS1 => $principals,
        FIELD1 => 'ObjectId',
        TABLE2 => 'Groups',
        FIELD2 => 'Id',
    );
    $objs->Limit(
        ALIAS => $groups,
        FIELD => 'Domain',
        VALUE => 'SystemInternal',
    );
    $deps->Add( in => $objs );

    # XXX: This ignores the myriad of "in" references from the Creator
    # and LastUpdatedBy columns.
}

sub Serialize {
    my $self = shift;
    return (
        Disabled => $self->PrincipalObj->Disabled,
        Principal => $self->PrincipalObj->UID,
        PrincipalId => $self->PrincipalObj->Id,
        $self->SUPER::Serialize(@_),
    );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    my $principal_uid = delete $data->{Principal};
    my $principal_id  = delete $data->{PrincipalId};
    my $disabled      = delete $data->{Disabled};

    my $obj = RT::User->new( RT->SystemUser );
    $obj->LoadByCols( Name => $data->{Name} );
    $obj->LoadByEmail( $data->{EmailAddress} ) unless $obj->Id;
    if ($obj->Id) {
        # User already exists -- merge

        # XXX: We might be merging a privileged user into an unpriv one,
        # in which case we should probably promote the unpriv user to
        # being privileged.  Of course, we don't know if the user being
        # imported is privileged yet, as its group memberships show up
        # later in the stream...
        $importer->MergeValues($obj, $data);
        $importer->SkipTransactions( $uid );

        # Mark both the principal and the user object as resolved
        $importer->Resolve(
            $principal_uid,
            ref($obj->PrincipalObj),
            $obj->PrincipalObj->Id
        );
        $importer->Resolve( $uid => ref($obj) => $obj->Id );
        return;
    }

    # Create a principal first, so we know what ID to use
    my $principal = RT::Principal->new( RT->SystemUser );
    my ($id) = $principal->Create(
        PrincipalType => 'User',
        Disabled => $disabled,
        ObjectId => 0,
    );
    $importer->Resolve( $principal_uid => ref($principal), $id );

    $importer->Postpone(
        for => $uid,
        uid => $principal_uid,
        column => "ObjectId",
    );

    return $class->SUPER::PreInflate( $importer, $uid, $data );
}

sub PostInflate {
    my $self = shift;
    RT->InitSystemObjects if $self->Name eq "RT_System";
}

1;
