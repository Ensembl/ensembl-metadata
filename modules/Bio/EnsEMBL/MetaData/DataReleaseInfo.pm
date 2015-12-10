
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

Bio::EnsEMBL::MetaData::DataReleaseInfo

=head1 SYNOPSIS

	  my $release_info =
		Bio::EnsEMBL::MetaData::GenomeDataReleaseInfo->new(
								   -ENSEMBL_VERSION=>83,
								   -EG_VERSION=>30,
								   -DATE=>'2015-12-07');

=head1 DESCRIPTION

Object encapsulating information about a particular release of Ensembl or Ensembl Genomes

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DataReleaseInfo;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
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
	( $self->{ensembl_version}, $self->{ensembl_genomes_version}, $self->{release_date} ) =
	  rearrange( [ 'ENSEMBL_VERSION', 'ENSEMBL_GENOMES_VERSION', 'RELEASE_DATE' ], @args );
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

sub is_current {
	my ( $self, $arg ) = @_;
	$self->{is_current} = $arg if ( defined $arg );
	return $self->{is_current};
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
			 release_date            => $in->release_date(), };
}

sub to_string {
	my ($self) = @_;
	return
	  join( '/',
			$self->ensembl_version(), ($self->ensembl_genomes_version()||'-'), ( $self->release_date() ) );
}

=head1 INTERNAL METHODS
=head2 dbID
  Arg        : (optional) dbID to set set
  Description: Gets/sets internal data_release_id used as database primary key
  Returntype : dbID string
  Exceptions : none
  Caller     : Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
  Status     : Stable
=cut

sub dbID {
	my ( $self, $arg ) = @_;
	if ( defined $arg ) {
		$self->{dbID} = $arg;
	}
	return $self->{dbID};
}

=head2 adaptor
  Arg        : (optional) adaptor to set set
  Description: Gets/sets GenomeInfoAdaptor
  Returntype : Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut

sub adaptor {
	my ( $self, $arg ) = @_;
	if ( defined $arg ) {
		$self->{adaptor} = $arg;
	}
	return $self->{adaptor};
}

1;
