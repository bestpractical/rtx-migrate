# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

package RT::Migrate::Importer;

use strict;
use warnings;

use Storable qw//;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->Init(@_);
    return $self;
}

sub Init {
    my $self = shift;
    my %args = (
        PreserveTicketIds => 0,
        OriginalId        => undef,
        Progress          => undef,
        @_,
    );

    # Should we attempt to preserve ticket IDs as they are created?
    $self->{PreserveTicketIds} = $args{PreserveTicketIds};
    if ($self->{PreserveTicketIds}) {
        my $tickets = RT::Tickets->new( RT->SystemUser );
        $tickets->UnLimit;
        warn "RT already contains tickets; preserving ticket IDs is unlikely to work"
            if $tickets->Count;
    }

    # Where to shove the original ticket ID
    $self->{OriginalId} = $args{OriginalId};
    if ($self->{OriginalId}) {
        my $cf = RT::CustomField->new( RT->SystemUser );
        $cf->LoadByName( Queue => 0, Name => $self->{OriginalId} );
        unless ($cf->Id) {
            warn "Failed to find global CF named $self->{OriginalId} -- creating one";
            $cf->Create(
                Queue => 0,
                Name  => $self->{OriginalId},
                Type  => 'FreeformSingle',
            );
        }
    }

    $self->{Progress} = $args{Progress};

    # Objects we've created
    $self->{UIDs} = {};

    # Columns we need to update when an object is later created
    $self->{Pending} = {};

    # What we created
    $self->{ObjectCount} = {};
}

sub Resolve {
    my $self = shift;
    my ($uid, $class, $id) = @_;
    $self->{UIDs}{$uid} = [ $class, $id ];
    return unless $self->{Pending}{$uid};

    for my $ref (@{$self->{Pending}{$uid}}) {
        my ($pclass, $pid) = @{ $self->{UIDs}{ $ref->{uid} } };
        my $obj = $pclass->new( RT->SystemUser );
        $obj->LoadByCols( Id => $pid );
        $obj->__Set(
            Field => $ref->{column},
            Value => $id,
        );
        $obj->__Set(
            Field => $ref->{classcolumn},
            Value => $class,
        ) if $ref->{classcolumn};
    }
    delete $self->{Pending}{$uid};
}

sub Lookup {
    my $self = shift;
    my ($uid) = @_;
    return $self->{UIDs}{$uid};
}

sub LookupObj {
    my $self = shift;
    my ($uid) = @_;
    my $ref = $self->Lookup( $uid );
    return unless $ref;
    my ($class, $id) = @{ $ref };

    my $obj = $class->new( RT->SystemUser );
    $obj->Load( $id );
    return $obj;
}

sub Postpone {
    my $self = shift;
    my %args = (
        for         => undef,
        uid         => undef,
        column      => undef,
        classcolumn => undef,
        @_,
    );
    my $uid = delete $args{for};
    push @{$self->{Pending}{$uid}}, \%args;
}

sub SkipTransactions {
    my $self = shift;
    my ($uid) = @_;
    $self->{skiptransactions}{$uid} = 1;
}

sub ShouldSkipTransaction {
    my $self = shift;
    my ($uid) = @_;
    return exists $self->{skiptransactions}{$uid};
}

sub MergeValues {
    my $self = shift;
    my ($obj, $data) = @_;
    for my $col (keys %{$data}) {
        next if defined $obj->__Value($col) and length $obj->__Value($col);
        next unless defined $data->{$col} and length $data->{$col};
        $obj->__Set( Field => $col, Value => $data->{$col} );
    }
}

sub SkipBy {
    my $self = shift;
    my ($column, $class, $uid, $data) = @_;

    my $obj = $class->new( RT->SystemUser );
    $obj->Load( $data->{$column} );
    return unless $obj->Id;

    $self->SkipTransactions( $uid );

    $self->Resolve( $uid => $class => $obj->Id );
    return $obj;
}

sub MergeBy {
    my $self = shift;
    my ($column, $class, $uid, $data) = @_;

    my $obj = $self->SkipBy(@_);
    return unless $obj;
    $self->MergeValues( $obj, $data );
    return 1;
}

sub Create {
    my $self = shift;
    my ($class, $uid, $data) = @_;
    return unless $class->PreInflate( $self, $uid, $data );

    # Remove the ticket id, unless we specifically want it kept
    delete $data->{id} if $class eq "RT::Ticket"
        and not $self->{PreserveTicketIds};

    my $obj = $class->new( RT->SystemUser );
    my ($id, $msg) = $obj->DBIx::SearchBuilder::Record::Create(
        %{$data}
    );
    die "Failed to create $uid: $msg\n" . Data::Dumper::Dumper($data) . "\n"
        unless $id;

    $self->{ObjectCount}{$class}++;
    $self->Resolve( $uid => $class, $id );

    # Load it back to get real values into the columns
    $obj = $class->new( RT->SystemUser );
    $obj->Load( $id );
    $obj->PostInflate( $self );

    return $obj;
}

sub Import {
    my $self = shift;
    my @files = @_;

    no warnings 'redefine';
    local *RT::Ticket::Load = sub {
        my $self = shift;
        my $id   = shift;
        $self->LoadById( $id );
        return $self->Id;
    };

    $self->Resolve( RT->System->UID => ref RT->System, RT->System->Id );
    $self->SkipTransactions( RT->System->UID );

    my %unglobal;
    my %new;
    for my $f (@files) {
        open(my $fh, "<", $f) or die "Can't read $f: $!";
        while (not eof($fh)) {
            my $loaded = Storable::fd_retrieve($fh);
            my ($class, $uid, $data) = @{$loaded};

            # If it's a queue, store its ID away, as we'll need to know
            # it to split global CFs into non-global across those
            # fields.  We do this before inflating, so that queues which
            # got merged still get the CFs applied
            push @{$new{$class}}, $uid
                if $class eq "RT::Queue";

            my $obj = $self->Create( $class, $uid, $data );
            next unless $obj;

            # If it's a ticket, we might need to create a
            # TicketCustomField for the previous ID
            if ($class eq "RT::Ticket" and $self->{OriginalId}) {
                my ($org, $origid) = $uid =~ /^RT::Ticket-(.*)-(\d+)$/;
                my ($id, $msg) = $obj->AddCustomFieldValue(
                    Field             => $self->{OriginalId},
                    Value             => "$org:$origid",
                    RecordTransaction => 0,
                );
                warn "Failed to add custom field to $uid: $msg"
                    unless $id;
            }

            # If it's a CF, we don't know yet if it's global (the OCF
            # hasn't been created yet) to store away the CF for later
            # inspection
            push @{$unglobal{"RT::Queue"}}, $uid
                if $class eq "RT::CustomField"
                    and $obj->LookupType =~ /^RT::Queue/;

            $self->{Progress}->($obj) if $self->{Progress};
        }
    }

    # Take global CFs which we made and make them un-global
    for my $class (keys %unglobal) {
        my @objs = grep {$_} map {$self->LookupObj( $_ )} @{$new{$class}};

        for my $uid (@{$unglobal{$class}}) {
            my $obj = $self->LookupObj( $uid );
            my $ocf = $obj->IsApplied( 0 ) or next;
            $ocf->Delete;
            $obj->AddToObject( $_ ) for @objs;
        }
    }

    # Anything we didn't see is an error
    if (keys %{$self->{Pending}}) {
        my @missing = sort keys %{$self->{Pending}};
        warn "The following UIDs were expected but never observed: @missing";
    }

    # Return creation counts
    return $self->ObjectCount;
}

sub ObjectCount {
    my $self = shift;
    return %{ $self->{ObjectCount} };
}

1;
