
=head1 LICENSE

Copyright [1999-2025] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::EventInfo

=head1 SYNOPSIS

	  my $event_info =
		Bio::EnsEMBL::MetaData::EventInfo->new(
								   -ENSEMBL_VERSION=>83,
								   -EG_VERSION=>30,
								   -DATE=>'2015-12-07',
                   -IS_CURRENT => 1);

=head1 DESCRIPTION

Object encapsulating information about an event that concerns a metadata object

=head1 SEE ALSO

Bio::EnsEMBL::MetaData::BaseInfo
Bio::EnsEMBL::MetaData::DBSQL::EventInfoAdaptor

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::EventInfo;
use base qw/Bio::EnsEMBL::MetaData::BaseInfo/;
use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

=head1 CONSTRUCTOR
=head2 new
  Arg [-SUBJECT]  : 
       object : subject of the event (GenomeInfo, DatabaseInfo, GenomeComparaInfo)
  Arg [-TYPE]    : 
       string - type of event
  Arg [-SOURCE] : 
       string -  ID of the source of the event

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
  my $subject;
  ( $subject, $self->{type}, $self->{source}, $self->{details},
    $self->{timestamp} )
    = rearrange( [ 'SUBJECT', 'TYPE', 'SOURCE', 'DETAILS', 'TIMESTAMP' ],
                 @args );
  $self->subject($subject);
  return $self;
}

=head1 ATTRIBUTE METHODS
=head2 subject
  Description: Get/set subject of event
  Arg        : (optional) Subject to set (must be GenomeInfo, DatabaseInfo or GenomeComparaInfo)
  Returntype : Bio::EnsEMBL::MetaData::BaseInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub subject {
  my ( $self, $subject ) = @_;
  if ( defined $subject ) {
    if ( !$subject->isa("Bio::EnsEMBL::MetaData::GenomeInfo") &&
         !$subject->isa("Bio::EnsEMBL::MetaData::DatabaseInfo") &&
         !$subject->isa("Bio::EnsEMBL::MetaData::GenomeComparaInfo") )
    {
      throw "Subject must be GenomeInfo, DatabaseInfo or GenomeComparaInfo";
    }
    $self->{subject} = $subject;
  }
  return $self->{subject};
}

=head2 type
  Description: Get/set subject of event
  Arg        : (optional) String
  Returntype : String
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
  Description: Get/set source of event
  Arg        : (optional) String
  Returntype : String
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub source {
  my ( $self, $source ) = @_;
  $self->{source} = $source if ( defined $source );
  return $self->{source};
}

=head2 details
  Description: Get/set details of event
  Arg        : (optional) String
  Returntype : String
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub details {
  my ( $self, $details ) = @_;
  $self->{details} = $details if ( defined $details );
  return $self->{details};

}

=head2 subject
  Description: Get timestamp of event
  Returntype : String (YYYY-MM-DD HH:MM::SS)
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub timestamp {
  my ( $self, $timestamp ) = @_;
  return $self->{timestamp};
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
  return { subject   => $in->subject()->to_hash(),
           type      => $in->type(),
           source    => $in->source(),
           details   => $in->details(),
           timestamp => $in->timestamp() };
}
=head2 to_string
  Description: Render as string suitable for display
  Returntype : String
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut
sub to_string {
  my ($self) = @_;
  return
    join( ":",
          $self->subject()->to_string(), $self->type(),
          $self->source(),               $self->details(),
          ( $self->timestamp() || '-' ) );
}

1;
