package RT::GroupMember;
use strict;
use warnings;

sub _InsertCGM {
    my $self = shift;

    my $cached_member = RT::CachedGroupMember->new( $self->CurrentUser );
    my $cached_id     = $cached_member->Create(
        Member          => $self->MemberObj,
        Group           => $self->GroupObj,
        ImmediateParent => $self->GroupObj,
        Via             => '0'
    );


    #When adding a member to a group, we need to go back
    #and popuplate the CachedGroupMembers of all the groups that group is part of .

    my $cgm = RT::CachedGroupMembers->new( $self->CurrentUser );

    # find things which have the current group as a member. 
    # $group is an RT::Principal for the group.
    $cgm->LimitToGroupsWithMember( $self->GroupId );
    $cgm->Limit(
        SUBCLAUSE => 'filter', # dont't mess up with prev condition
        FIELD => 'MemberId',
        OPERATOR => '!=',
        VALUE => 'main.GroupId',
        QUOTEVALUE => 0,
        ENTRYAGGREGATOR => 'AND',
    );

    while ( my $parent_member = $cgm->Next ) {
        my $parent_id = $parent_member->MemberId;
        my $via       = $parent_member->Id;
        my $group_id  = $parent_member->GroupId;

        my $other_cached_member =
            RT::CachedGroupMember->new( $self->CurrentUser );
        my $other_cached_id = $other_cached_member->Create(
            Member          => $self->MemberObj,
                      Group => $parent_member->GroupObj,
            ImmediateParent => $parent_member->MemberObj,
            Via             => $parent_member->Id
        );
        unless ($other_cached_id) {
            $RT::Logger->err( "Couldn't add " . $self->MemberId
                  . " as a submember of a supergroup" );
            return;
        }
    }

    return $cached_id;
}

sub Dependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::Dependencies($walker, $deps);

    $deps->Add( out => $self->GroupObj->Object );
    $deps->Add( out => $self->MemberObj->Object );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    my $obj = RT::GroupMember->new( RT->SystemUser );
    $obj->LoadByCols(
        GroupId  => $data->{GroupId},
        MemberId => $data->{MemberId},
    );
    if ($obj->id) {
        $importer->Resolve( $uid => ref($obj) => $obj->Id );
        return;
    }

    return 1;
}

sub PostInflate {
    my $self = shift;

    $self->_InsertCGM;
}

1;
