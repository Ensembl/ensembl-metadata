
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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::MetaData::DataReleaseInfo

=head1 SYNOPSIS

	  my $release_info =
		Bio::EnsEMBL::MetaData::GenomeDataReleaseInfo->new(
								   -ENSEMBL_VERSION=>83,
								   -EG_VERSION=>30,
								   -DATE=>'2015-12-07',
                   -IS_CURRENT=>1);

=head1 DESCRIPTION

Object encapsulating information about a particular release of Ensembl or Ensembl Genomes

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::BaseInfo
Bio::EnsEMBL::MetaData::DBSQLDataReleaseInfoAdaptor

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DataReleaseInfo;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
use Bio::EnsEMBL::MetaData::DatabaseInfo;
use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use POSIX 'strftime';
use Bio::EnsEMBL::ApiVersion;

=head1 CONSTRUCTOR
=head2 new
  Arg [-ENSEMBL_VERSION]  : 
       int - Ensembl version (by default current version from API)
  Arg [-EG_VERSION]    : 
       int - optional Ensembl Genomes version
  Arg [-RELEASE_DATE] : 
       string - date of the release as YYYY-MM-DD
  Arg [-IS_CURRENT] :
       int - optional current release

  Example    : $info = Bio::EnsEMBL::MetaData::DataReleaseInfo->new(...);
  Description: Creates a new release info object
  Returntype : Bio::EnsEMBL::MetaData::DataReleaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut
sub new {
	my ( $class, @args ) = @_;
	my $self = $class->SUPER::new(@args);
	( $self->{ensembl_version}, $self->{ensembl_genomes_version}, $self->{release_date} ,$self->{is_current} ) =
	  rearrange( [ 'ENSEMBL_VERSION', 'ENSEMBL_GENOMES_VERSION', 'RELEASE_DATE', 'IS_CURRENT' ], @args );
	$self->{ensembl_version} ||= software_version();
	$self->{release_date} ||= strftime '%Y-%m-%d', localtime;
	return $self;
}

=head1 ATTRIBUTE METHODS
=head2 ensembl_version
  Arg        : (optional) version to set
  Description: Gets/sets name Ensembl version
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub ensembl_version {
	my ( $self, $arg ) = @_;
	$self->{ensembl_version} = $arg if ( defined $arg );
	return $self->{ensembl_version};
}

=head2 ensembl_genomes_version
  Arg        : (optional) version to set
  Description: Gets/sets name Ensembl version
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub ensembl_genomes_version {
	my ( $self, $arg ) = @_;
	$self->{ensembl_genomes_version} = $arg if ( defined $arg );
	return $self->{ensembl_genomes_version};
}
=head2 is_current
  Arg        : (optional) Integer to set if current
  Description: Gets/sets if release is current
  Returntype : Integer (1 if current)
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub is_current {
	my ( $self, $arg ) = @_;
	$self->{is_current} = $arg if ( defined $arg );
	return $self->{is_current};
}

=head2 databases
  Arg        : (optional) Arrayref of DatabaseInfo objects
  Description: Databases associated with this release
  Returntype : None
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub databases {
  my ($self, $databases) = @_;
  if(defined $databases) {
    $self->{databases} = $databases;
  }
  $self->_load_child( 'databases', '_fetch_databases' );
  return $self->{databases};
}

=head2 release_date
  Arg        : (optional) version to set
  Description: Gets/sets name Ensembl version
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub release_date {
	my ( $self, $arg ) = @_;
	$self->{release_date} = $arg if ( defined $arg );
	return $self->{release_date};
}

=head1 UTILITY METHODS
=head2 add_database
  Arg        : String - Name of database
  Arg        : String - Name of Ensembl division
  Description: Associate a database with this release
  Returntype : None
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub add_database {
  my ( $self, $dbname, $division ) = @_;
  push @{$self->{databases}}, Bio::EnsEMBL::MetaData::DatabaseInfo->new(-DBNAME=>$dbname, -DIVISION=>$division, -SUBJECT => $self);
  return;
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
	return { ensembl_version => $in->ensembl_version(),
			 ensembl_genomes_version      => $in->ensembl_genomes_version(),
			 release_date            => $in->release_date(),
       is_current              => $in->is_current() };
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
	return
	  join( '/',
			$self->ensembl_version(), ($self->ensembl_genomes_version()||'-'), ( $self->release_date() ) );
}

1;
