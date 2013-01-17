package RT::Group;
use strict;
use warnings;

sub InstanceObj {
    my $self = shift;

    my $class;
    if ( $self->Domain eq 'ACLEquivalence' ) {
        $class = "RT::User";
    } elsif ($self->Domain eq 'RT::Queue-Role') {
        $class = "RT::Queue";
    } elsif ($self->Domain eq 'RT::Ticket-Role') {
        $class = "RT::Ticket";
    }

    return unless $class;

    my $obj = $class->new( $self->CurrentUser );
    $obj->Load( $self->Instance );
    return $obj;
}

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    my $instance = $self->InstanceObj;
    $deps->Add( out => $instance ) if $instance;

    # Group members records, unless we're a system group
    if ($self->Domain ne "SystemInternal") {
        my $objs = RT::GroupMembers->new( $self->CurrentUser );
        $objs->LimitToMembersOfGroup( $self->PrincipalId );
        $deps->Add( in => $objs );
    }

    # Group member records group belongs to
    my $objs = RT::GroupMembers->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'MemberId', VALUE => $self->PrincipalId );
    $deps->Add( in => $objs );
}

sub Serialize {
    my $self = shift;
    my %args = (@_);
    my %store = $self->SUPER::Serialize(@_);

    my $instance = $self->InstanceObj;
    $store{Instance} = \($instance->UID) if $instance;

    $store{Disabled} = $self->PrincipalObj->Disabled;
    $store{Principal} = $self->PrincipalObj->UID;
    $store{PrincipalId} = $self->PrincipalObj->Id;
    return %store;
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    my $principal_uid = delete $data->{Principal};
    my $principal_id  = delete $data->{PrincipalId};
    my $disabled      = delete $data->{Disabled};

    # Inflate refs into their IDs
    $class->SUPER::PreInflate( $importer, $uid, $data );

    # Factored out code, in case we find an existing version of this group
    my $obj = RT::Group->new( RT->SystemUser );
    my $duplicated = sub {
        $importer->SkipTransactions( $uid );
        $importer->Resolve(
            $principal_uid,
            ref($obj->PrincipalObj),
            $obj->PrincipalObj->Id
        );
        $importer->Resolve( $uid => ref($obj), $obj->Id );
        return;
    };

    # Go looking for the pre-existing version of the it
    if ($data->{Domain} eq "ACLEquivalence") {
        $obj->LoadACLEquivalenceGroup( $data->{Instance} );
        return $duplicated->() if $obj->Id;

        # Update the name and description for the new ID
        $data->{Name} = 'User '. $data->{Instance};
        $data->{Description} = 'ACL equiv. for user '.$data->{Instance};
    } elsif ($data->{Domain} eq "UserDefined") {
        $data->{Name} = $importer->Qualify($data->{Name});
        $obj->LoadUserDefinedGroup( $data->{Name} );
        if ($obj->Id) {
            $importer->MergeValues($obj, $data);
            return $duplicated->();
        }
    } elsif ($data->{Domain} =~ /^(SystemInternal|RT::System-Role)$/) {
        $obj->LoadByCols( Domain => $data->{Domain}, Type => $data->{Type} );
        return $duplicated->() if $obj->Id;
    } elsif ($data->{Domain} eq "RT::Queue-Role") {
        $obj->LoadQueueRoleGroup( Queue => $data->{Instance}, Type => $data->{Type} );
        return $duplicated->() if $obj->Id;
    }

    my $principal = RT::Principal->new( RT->SystemUser );
    my ($id) = $principal->Create(
        PrincipalType => 'Group',
        Disabled => $disabled,
        ObjectId => 0,
    );

    # Now we have a principal id, set the id for the group record
    $data->{id} = $id;

    $importer->Resolve( $principal_uid => ref($principal), $id );

    $importer->Postpone(
        for => $uid,
        uid => $principal_uid,
        column => "ObjectId",
    );

    return 1;
}

sub PostInflate {
    my $self = shift;

    my $cgm = RT::CachedGroupMember->new($self->CurrentUser);
    $cgm->Create(
        Group  => $self->PrincipalObj,
        Member => $self->PrincipalObj,
        ImmediateParent => $self->PrincipalObj
    );
}

1;
