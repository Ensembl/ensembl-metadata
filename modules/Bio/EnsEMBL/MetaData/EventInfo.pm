
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

Bio::EnsEMBL::MetaData::EventInfo

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

package Bio::EnsEMBL::MetaData::EventInfo;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::ApiVersion;

=head1 CONSTRUCTOR
=head2 new
  Arg [-SUBJECT]  : 
       object : 
  Arg [-TYPE]    : 
       int - optional Ensembl Genomes version
  Arg [-SOURCE] : 
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
  ( $self->{subject}, $self->{type}, $self->{source},
    $self->{details}, $self->{timestamp} )
    = rearrange( [ 'SUBJECT', 'TYPE', 'SOURCE', 'DETAILS', 'TIMESTAMP' ],
                 @args );
  return $self;
}

sub subject {
  my ( $self, $subject ) = @_;
  $self->{subject} = $subject if ( defined $subject );
  return $self->{subject};
}

sub type {
  my ( $self, $type ) = @_;
  $self->{type} = $type if ( defined $type );
  return $self->{type};
}

sub source {
  my ( $self, $source ) = @_;
  $self->{source} = $source if ( defined $source );
  return $self->{source};
}

sub details {
  my ( $self, $details ) = @_;
  $self->{details} = $details if ( defined $details );
  return $self->{details};

}

sub timestamp {
  my ( $self, $timestamp ) = @_;
  return $self->{timestamp};

}

=head1 ATTRIBUTE METHODS
=head2 to_hash
  Description: Render as plain hash suitable for export as JSON/XML
  Returntype : Hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub to_hash {
  my ($in) = @_;
  return { subject   => $in->subject()->to_hash(),
           type      => $in->type(),
           source    => $in->source(),
           details   => $in->details(),
           timestamp => $in->timestamp() };
}

sub to_string {
  my ($self) = @_;
  return
    join( ":",
          $self->subject()->to_string(),
          $self->type(), $self->source(), $self->details(),
          ($self->timestamp()||'-') );
}

1;
