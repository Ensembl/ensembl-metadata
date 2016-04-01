
=head1 LICENSE

Copyright [2009-2016] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::MetaDataDumper

=head1 SYNOPSIS

# usage of concrete implementations
my $dumper = Bio::EnsEMBL::MetaData::MetaDataDumper::MyDumper->new();

# sequential dumping to multiple files in parallel
my $opts = {
  division => ['EnsemblFungi','EnsemblProtists'];
  file => 'MyFile.txt'
};
# set to dump to common "all" file as well as division
$dump_all = 1;
# open files
$dumper->start($opts->{division}, $dumper->{file}, $dump_all);
for my $md (@metadata) {
  $dumper->write_metadata($md, $dump_all); # dump to divisions and 
}
# close files
$dumper->end($opts->{division}, $dumper->{file}, $dump_all);

# dumping in one go (can be expensive to render)
$dumper->dump_metadata(\@metadata, "my_file.txt", ['EnsemblMetazoa'], $dump_all);

=head1 DESCRIPTION

Base class for rendering details from an instance of Bio::EnsEMBL::MetaData::GenomeInfo. 
Designed for dumping to multiple per-division files in parallel including a common "all" 
file, (using start, write_metadata and end) or for one-off use (using dump_metadata).

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::MetaDataDumper;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Log::Log4perl qw(get_logger);
use Data::Dumper;
use Carp qw(croak cluck);
use strict;
use warnings;

=head1 SUBROUTINES/METHODS

=head2 new
  Description: Creates a new dumper object
  Returntype : Bio::EnsEMBL::MetaData::MetaDataDumper
  Exceptions : none
  Caller     : internal
  Status     : Stable

=cut

sub new {
  my ( $proto, @args ) = @_;
  my $class = ref($proto) || $proto;
  my $self = bless( {}, $class );
  $self->{logger} = get_logger();
  $self->{all}    = 'all';
  return $self;
}

=head2 dump_metadata
  Description: Write supplied metadata to file
  Arg        : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Arg        : File to write to
  Arg        : Arrayref of divisions
  Arg        : Whether to dump to "all" file
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub dump_metadata {
  my ( $self, $metadata, $file, $divisions, $dump_all ) = @_;
  # start
  $self->start( $file, $divisions, $dump_all );
  # iterate
  for my $md (@$metadata) {
    if ( scalar(@$divisions) > 1 ) {
      $self->write_metadata( $md, $self->{all} );
    }
    $self->write_metadata( $md, $md->{division} );
  }
  # end
  $self->end();
  return;

}

=head2 write_metadata
  Arg        : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Arg        : Division to write to
  Description: Write metadata to division files
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub write_metadata {
  my ( $self, $metadata, $division ) = @_;
  my $fh = $self->{files}{$division};
  if ( defined $fh ) {
    $self->_write_metadata_to_file( $metadata, $fh,
                                    $self->{count}->{$division} );
    $self->{count}->{$division} += 1;
  }
  return;
}

=head2 start
  Description: Start writing to output file(s)
  Arg        : Arrayref of strings representing divisions to dump
  Arg        : Basename of file to write to
  Arg        : Whether to dump to "all" file
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub start {
  my ( $self, $divisions, $file, $dump_all ) = @_;
  $self->{files}     = {};
  $self->{filenames} = {};
  $self->logger()->debug("Opening output files");
  for my $division ( @{$divisions} ) {
    ( my $out_file = $file ) =~ s/(.+)(\.[^.]+)$/$1_$division$2/;
    my $fh;
    $self->logger()
      ->debug("Opening output file $out_file for division $division");
    open( $fh, '>', $out_file ) || croak "Could not open $out_file for writing";
    $self->{files}->{$division}     = $fh;
    $self->{filenames}->{$division} = $out_file;
    $self->{count}{$division}       = 0;
  }
  if ( defined $dump_all && $dump_all == 1 ) {
    my $fh;
    $self->logger()->debug("Opening output file $file");
    open( $fh, '>', $file ) || croak "Could not open $file for writing";
    $self->{files}->{ $self->{all} }     = $fh;
    $self->{filenames}->{ $self->{all} } = $file;
    $self->{count}{ $self->{all} }       = 0;
  }
  $self->{files_handles} = {};
  $self->logger()
    ->debug(
           "Opened " . scalar( values %{ $self->{files} } ) . " output files" );
  return;
} ## end sub start

=head2 end
  Description: Stop writing to output file(s) and close handles
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub end {
  my ($self) = @_;
  $self->logger()->debug("Closing all file handles");
  for my $fh ( values %{ $self->{files} } ) {
    $self->logger()->debug("Closing file handle");
    close($fh) || cluck "Could not close file handle for writing";
  }
  $self->logger()
    ->debug(
           "Closed " . scalar( values %{ $self->{files} } ) . " file handles" );
  return;
}

=head2 _write_metadata_to_file
  Arg        : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Arg        : File handle to write to
  Description: Stub for writing to a file - implement in subclasses
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _write_metadata_to_file {
  my ( $self, $metadata, $fh ) = @_;
  throw "Unimplemented subroutine do_dump() in " . ref($self) .
    ". Please implement";
  return;
}

=head1 INTERNAL METHODS
=head2 logger
  Description: Get logger
  Returntype : Log4perl::Logger
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub logger {
  my ($self) = @_;
  return $self->{logger};
}

=head2 yesno
  Description: Turn defined/integer into Y/N
  Arg        : Integer 1/0
  Returntype : String
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub yesno {
  my ( $self, $num ) = @_;
  return ( defined $num && $num + 0 > 0 ) ? 'Y' : 'N';
}

=head2 metadata_to_hash
  Description: Turn metadata into hash
  Arg        : Arrayref of Bio::EnsEMBL::MetaData::GenomeInfo
  Returntype : Hashref
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub metadata_to_hash {
  my ( $self, $metadata ) = @_;
  my $genomes = [];
  for my $md ( @{$metadata} ) {
    push @$genomes, $md->to_hash(1);
  }
  return { genome => $genomes };
}

1;
