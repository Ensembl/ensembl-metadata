
=head1 LICENSE

Copyright [1999-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::MetaData::DatabaseInfo

=head1 SYNOPSIS

my $info = Bio::EnsEMBL::MetaData::DatabaseInfo->new(-DBNAME=>"homo_sapiens_core_84_38", -SUBJECT=>$human_genome);
print $info->dbname();

=head1 DESCRIPTION

Object encapsulating information about a database that can be associated with genomes or releases.

=head1 AUTHOR

Dan Staines

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::BaseInfo
Bio::EnsEMBL::MetaData::DBSQLDatabaseInfoAdaptor

=cut

package Bio::EnsEMBL::MetaData::DatabaseInfo;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

=head1 CONSTRUCTOR
=head2 new
  Arg [-SUBJECT] : Bio::EnsEMBL::MetaData::GenomeInfo or Bio::EnsEMBL::MetaData::DataReleaseInfo
  Arg [-DBNAME] : string - database name
  Arg [-TYPE]  : 
       string - database type (optional - if absent derived from dbname)
  Arg [-DIVISION]    : 
       string : optional Ensembl division (for use when subject is DataRelease)
  Arg [-SPECIES_ID] : 
       Integer - optional species_id (for use when subject is GenomeInfo)

  Example    : $info = Bio::EnsEMBL::MetaData::DatabaseInfo->new(...);
  Description: Creates a new database info object
  Returntype : Bio::EnsEMBL::MetaData::DatabaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  my $subject;
  ( $self->{type}, $self->{division}, $self->{dbname}, $subject,
    $self->{species_id} )
    = rearrange( [ 'TYPE', 'DIVISION', 'DBNAME', 'SUBJECT', 'SPECIES_ID' ],
                 @args );
  if ( !defined $self->{type} ) {
    $self->{type} = _parse_type( $self->dbname() );
  }
  $self->{species_id} ||= 1;
  $self->{subject} = $subject;
  return $self;
}

=head1 ATTRIBUTE METHODS
=head2 division
  Arg        : (optional) division to set
  Description: Gets/sets Ensembl Genomes division
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub division {
  my ( $self, $division ) = @_;
  $self->{division} = $division if ( defined $division );
  return $self->{division};
}

=head2 species_id
  Arg        : (optional) species_id to set
  Description: Gets/sets species_id
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub species_id {
  my ( $self, $species_id ) = @_;
  $self->{species_id} = $species_id if ( defined $species_id );
  return $self->{species_id};
}

=head2 dbname
  Arg        : (optional) dbname to set
  Description: Gets/sets dbname
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub dbname {
  my ( $self, $dbname ) = @_;
  if ( defined $dbname ) {
    $self->{dbname} = $dbname;
    if ( !defined $self->{type} ) {
      $self->{type} = _parse_type( $self->dbname() );
    }
  }
  return $self->{dbname};
}

=head2 type
  Arg        : (optional) database type to set
  Description: Gets/sets database type
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub type {
  my ( $self, $type ) = @_;
  $self->{type} = $type if ( defined $type );
  return $self->{type};
}

=head2 subject
  Arg        : (optional) subject
  Description: Gets/sets subject that database is associated with
  Returntype : Bio::EnsEMBL::MetaData::GenomeInfo or Bio::EnsEMBL::MetaData::DataReleaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub subject {
  my ( $self, $subject ) = @_;
  if ( defined $subject ) {
    if ( !$subject->isa("Bio::EnsEMBL::MetaData::GenomeInfo") &&
         !$subject->isa("Bio::EnsEMBL::MetaData::DataReleaseInfo") )
    {
      throw
"The subject of a DatabaseInfo object must be GenomeInfo or DataReleaseInfo";
    }
    $self->{subject} = $subject;
  }
  return $self->{subject};
}

=head2 to_hash
  Description: Render as plain hash suitable for export as JSON/XML
  Returntype : Hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub to_hash {
  my ($in) = @_;
  return { division => $in->division(),
           type     => $in->type(),
           dbname   => $in->dbname(), };
}

=head2 to_hash
  Description: Render as string for display
  Returntype : String
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub to_string {
  my ($self) = @_;
  return join( '/', $self->division(), $self->type(), $self->dbname() );
}

=head2 _parse_type
  Description: Derive type from database name
  Returntype : String
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _parse_type {
  my ($dbname) = @_;
  if ( $dbname =~ m/_mart_/ ) {
    return 'mart';
  }
  elsif ( $dbname =~ m/_ontology(?:_|$)/ ) {
    return 'ontology';
  }
  elsif ( $dbname =~ m/_ancestral_/ ){
    return 'other';
  }
  else {
    if ($dbname =~ m/^.+_([a-z]+)_[0-9]+_?[0-9]+?_[0-9a-z]+$/){
      return $1;
    }
    else {
      return 'other';
    }
  }
}

1;
