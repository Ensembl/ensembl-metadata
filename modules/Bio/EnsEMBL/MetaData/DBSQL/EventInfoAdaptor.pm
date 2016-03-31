
=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor

=head1 SYNOPSIS

my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_adaptor();
my $md = $gdba->fetch_by_name("arabidopsis_thaliana");

=head1 DESCRIPTION

Adaptor for storing and retrieving GenomeInfo objects from MySQL genome_info database

To start working with an adaptor:

# getting an adaptor
## adaptor for latest public EG release
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_eg_adaptor();
## adaptor for specified public EG release
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->build_eg_adaptor(21);
## manually specify a given database
my $dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(
-USER=>'anonymous',
-PORT=>4157,
-HOST=>'mysql-eg-publicsql.ebi.ac.uk',
-DBNAME=>'genome_info_21');
my $gdba = Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor->new(-DBC=>$dbc);

To find genomes, use the fetch methods e.g.

# find a genome by name
my $genome = $gdba->fetch_by_name('arabidopsis_thaliana');

# find and iterate over all genomes
for my $genome (@{$gdba->fetch_all()}) {
	print $genome->name()."\n";
}

# find and iterate over all genomes from plants
for my $genome (@{$gdba->fetch_all_by_division('EnsemblPlants')}) {
	print $genome->name()."\n";
}

# find and iterate over all genomes with variation
for my $genome (@{$gdba->fetch_all_with_variation()}) {
	print $genome->name()."\n";
}

# find all comparas for the division of interest
my $comparas = $gdba->fetch_all_compara_by_division('EnsemblPlants');

# find the peptide compara
my ($compara) = grep {$_->is_peptide_compara()} @$comparas;
print $compara->division()." ".$compara->method()."(".$compara->dbname().")\n";

# print out all the genomes in this compara
for my $genome (@{$compara->genomes()}) {
	print $genome->name()."\n";
}

=head1 Author

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

sub update {
  my ( $self, $event ) = @_;
  throw "Cannot update an event";
}

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
