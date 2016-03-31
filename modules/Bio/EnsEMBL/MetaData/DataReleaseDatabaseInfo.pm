
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

Bio::EnsEMBL::MetaData::DataReleaseDatabaseInfo

=head1 SYNOPSIS

=head1 DESCRIPTION

Object encapsulating information about a non-genome specific database in a release

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::DataReleaseDatabaseInfo;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);

=head1 CONSTRUCTOR
=head2 new
  Arg [-TYPE]  : 
       string - database type
  Arg [-DIVISION]    : 
       string : Ensembl division
  Arg [-DBNAME] : 
       string - database name

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
	( $self->{type}, $self->{division}, $self->{dbname}, $self->{release}) =
	  rearrange( [ 'TYPE', 'DIVISION', 'DBNAME', 'RELEASE' ], @args );
	 if(!defined $self->{type}) {	   
    $self->{type} = _parse_type($self->dbname());
	 } 
	return $self;
}

sub _parse_type {
  my ( $dbname ) = @_;
  if($dbname =~ m/mart/) {
    return 'mart';
  } else {
    return 'other';
  }
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
  $self->{dbname} = $dbname if ( defined $dbname );
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
sub release {
  my ( $self, $release ) = @_;
  $self->{release} = $release if ( defined $release );
  return $self->{release};
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
			 type      => $in->type(),
			 dbname            => $in->dbname(), };
}

sub to_string {
	my ($self) = @_;
	return
	  join( '/',
			$self->division(), $self->type(), $self->dbname());
}

1;
