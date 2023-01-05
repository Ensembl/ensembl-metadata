
=head1 LICENSE

Copyright [1999-2023] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod

=head1 NAME

Bio::EnsEMBL::MetaData::DBSQL::EventInfoAdaptor

=head1 SYNOPSIS

# metadata_db is an instance of MetaDataDBAdaptor
my $adaptor = $metadata_db->get_EventInfoAdaptor();
my $events = $adaptor->fetch_events($info);

=head1 DESCRIPTION

Adaptor for storing and retrieving EventInfo objects from MySQL ensembl_metadata database

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::EventInfo
Bio::EnsEMBL::MetaData::DatabaseInfo
Bio::EnsEMBL::MetaData::GenomeComparaInfo
Bio::EnsEMBL::MetaData::GenomeInfo

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DBSQL::EventInfoAdaptor;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::MetaData::DBSQL::BaseInfoAdaptor/;

use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw( throw );
use Bio::EnsEMBL::MetaData::DataReleaseInfo;
use List::MoreUtils qw(natatime);

=head1 METHODS
=cut

my $tables = {"Bio::EnsEMBL::MetaData::GenomeInfo"        => "genome",
              "Bio::EnsEMBL::MetaData::GenomeComparaInfo" => "compara_analysis",
              "Bio::EnsEMBL::MetaData::DatabaseInfo" => "data_release_database"
};
=head2 store
  Arg        : Bio::EnsEMBL::MetaData::DatabaseInfo
  Description: Store the supplied object
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub store {
  my ( $self, $event ) = @_;
  my $table       = $tables->{ ref( $event->subject() ) };
  my $id          = $table . '_id';
  my $event_table = $table . '_event';
  if(!defined $event->subject()->dbID()) {
    throw "Cannot store an event on an object that has not been stored first";
  }
  if ( !defined $event->dbID() ) {
    $self->dbc()->sql_helper()->execute_update(
      -SQL => qq/insert into $event_table($id,type,source,details) 
values (?,?,?,?)/,
      -PARAMS => [ $event->subject()->dbID(), $event->type(),
                   $event->source(),          $event->details() ],
      -CALLBACK => sub {
        my ( $sth, $dbh, $rv ) = @_;
        $event->dbID( $dbh->{mysql_insertid} );
      } );
    $event->adaptor($self);
    $self->_store_cached_obj($event);
  }
  else {
    throw "Cannot store an event that has been stored already";
  }
  return;
}
=head2 update
  Arg        : Bio::EnsEMBL::MetaData::DatabaseInfo
  Description: Update the supplied object (must be previously stored)
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub update {
  my ( $self, $event ) = @_;
  throw "Cannot update an event";
}
=head2 fetch_events
  Arg        : Bio::EnsEMBL::MetaData::GenomeInfo
              or Bio::EnsEMBL::MetaData::GenomeComparaInfo
              or Bio::EnsEMBL::MetaData::DatabaseInfo
  Description: Retrieve events associated with the supplied object
  Returntype : Arrayref of Bio::EnsEMBL::MetaData::EventInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub fetch_events {
  my ( $self, $subject ) = @_;
  my $table          = $tables->{ ref($subject) };
  my $id             = $table . '_id';
  my $event_table    = $table . '_event';
  my $event_table_id = $event_table . '_id';
  return $self->dbc()->sql_helper()->execute(
    -SQL => qq/select $event_table_id, type, source, details, creation_time 
from $event_table where $id=? order by creation_time asc/,
    -CALLBACK => sub {
      my @row = @{ shift @_ };
      return
        Bio::EnsEMBL::MetaData::EventInfo->new( -DBID      => $row[0],
                                                -SUBJECT   => $subject,
                                                -TYPE      => $row[1],
                                                -SOURCE    => $row[2],
                                                -DETAILS   => $row[3],
                                                -TIMESTAMP => $row[4] );
    },
    -PARAMS => [ $subject->dbID() ] );
}

1;
