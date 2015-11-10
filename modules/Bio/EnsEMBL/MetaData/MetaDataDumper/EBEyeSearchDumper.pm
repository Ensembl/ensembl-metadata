=pod
=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
=cut

package Bio::EnsEMBL::MetaData::MetaDataDumper::EBEyeSearchDumper;
use base qw( Bio::EnsEMBL::MetaData::MetaDataDumper );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Carp;
use XML::Generator ':pretty';
use POSIX qw(strftime);

use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  $self->{file}     ||= "species_search.xml";
  $self->{division} ||= 1;
  $self->{date} = strftime "%Y-%m-%d", localtime;
  return $self;
}


sub start {
  my ($self, $divisions, $file, $dump_all) = @_;
  $self->SUPER::start($divisions, $file, $dump_all);
  if(defined $dump_all && $dump_all == 1) {
      $self->_start_file($self->{all}, $self->{files}->{$self->{all}});
  }
  for my $division (@$divisions) {
      $self->_start_file($division, $self->{files}->{$division});
  } 
  return;
}

sub _start_file {
    my ($self, $division, $fh) = @_;
	print $fh <<END;
<database>
    <name>Ensembl Genomes $division</name>
    <description>Ensembl Genomes genome metadata ($division)</description>
    <release>EG_RELEASE</release>
    <release_date>EG_RELEASE_DATE</release_date>
    <entries>
END
    return;
}

sub _na_field {
   my ($attrs,$val) = @_;
   if(defined $val && $val ne '') {
       return field($attrs,$val);
   } else {
     return '';
   }
}

sub _bool_field {
    my ($attrs,$val ) = @_;
    return field($attrs,$val||'0');
}

sub _fields {
   my ($attrs,$vals) = @_;
   my @fields = ();
   for my $val (@$vals) {

   }
   return \@fields;
}

sub _write_metadata_to_file {
    my ($self, $md, $fh, $count) = @_;
    my @fields = ( field({name=>"division"},$md->division()),
                   _na_field({name=>"strain"},$md->strain()),
                   _na_field({name=>"serotype"},$md->serotype()),
                   _na_field({name=>"assembly_id"},$md->assembly_id()),
                   field({name=>"assembly_name"},$md->assembly_name()),
                   field({name=>"genebuild"},$md->genebuild()),
                   _bool_field({name=>"is_reference"},$md->is_reference()),
                   _bool_field({name=>"has_pan_compara"},$md->has_pan_compara()),
                   _bool_field({name=>"has_peptide_compara"},$md->has_peptide_compara()),
                   _bool_field({name=>"has_synteny"},$md->has_synteny()),
                   _bool_field({name=>"has_genome_alignments"},$md->has_genome_alignments()),
                   _bool_field({name=>"has_other_alignments"},$md->has_other_alignments()),
                   _bool_field({name=>"has_variations"},$md->has_variations()));
    for my $alias (@{$md->aliases()}) {
        push @fields, field({name=>"alias"},$alias);
    }
    
  print $fh entry(
    {id=>$md->species()},
    name($md->name()),
    cross_references(
        &ref({dbkey=>"ncbi_taxonomy",dbname=>$md->taxonomy_id()})
    ),
    dates(
        date({type=>"creation",value=>$self->{date}}),
        date({type=>"last_modification",value=>$self->{date}}),
    ),
    additional_fields(
        @fields
    )
    );
  return;
}

sub _end_file {
    my ($self,$fh,$cnt) = @_;
    print $fh <<END;
    </entries>
    <entry_count>$cnt</entry_count>
</database>
END
    return;
}


sub end {
  my ($self) = @_;
  for my $division (keys %{$self->{files}}) {
      $self->_end_file($self->{files}{$division},$self->{count}{$division});
  }
  $self->SUPER::end();
  return;
}


1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::MetaData::MetaDataDumper::EBEyeSearchDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation to dump metadata details to an XML file for indexing by EBEye

=head1 SUBROUTINES/METHODS

=head2 new

=head2 dump_metadata
Description : Dump metadata to the file supplied by the constructor 
Argument : Hash of details

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
