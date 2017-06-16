=head1 LICENSE

Copyright [2009-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::MetaData::MetaDataDumper::TT2MetaDataDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

Implementation to dump metadata details to a TemplateToolKit file.
See Bio::EnsEMBL::MetaData::MetaDataDumper for method details.

=head1 SEE ALSO
Bio::EnsEMBL::MetaData::MetaDataDumper

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::MetaDataDumper::TT2MetaDataDumper;
use base qw( Bio::EnsEMBL::MetaData::MetaDataDumper );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Carp;
use XML::Simple;
use strict;
use warnings;

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  $self->{file}     ||= 'species.tt2';
  $self->{division} ||= 'Ensembl';
  $self->{div_links} = {
					  EnsemblBacteria => "http://bacteria.ensembl.org/",
					  EnsemblFungi    => "http://fungi.ensembl.org/",
					  EnsemblMetazoa  => "http://metazoa.ensembl.org/",
					  EnsemblProtists => "http://protists.ensembl.org/",
					  EnsemblPlants   => "http://plants.ensembl.org/",
					  Ensembl         => "http://www.ensembl.org/",};
  $self->{div_names} = {EnsemblBacteria => "Bacteria",
						EnsemblFungi    => "Fungi",
						EnsemblMetazoa  => "Metazoa",
						EnsemblProtists => "Protists",
						EnsemblPlants   => "Plants",
						Ensembl         => "Ensembl",};

  return $self;
}

sub do_dump {
  my ($self, $metadata, $outfile) = @_;
  my $eg_version = $metadata->{genome}->[0]->{dbname};
  $eg_version =~ s/[a-z]+_([0-9]+)_[0-9]+_[0-9]+/$1/;
  my $td  = '<td>';
  my $tdx = '</td>';
  my $tr  = '<tr>';
  my $trx = '</tr>';
  open(my $tt2_file, '>', $outfile) ||
	croak "Could not write to " . $outfile;
  print $tt2_file <<"ENDHEAD";
	<style type="text/css" title="currentStyle">
    	\@import "/static/css/grid.css";
	</style>

	<script type="text/javascript" charset="utf-8" src="/static/js/jquery.dataTables.min.js"></script>

	<script type="text/javascript">
	$(document).ready( function () {
   	$('#species_list').dataTable({
    "sPaginationType": "full_numbers",
    "iDisplayLength": 25,
    "aLengthMenu": [[25, 50, 100, -1], [25, 50, 100, "All"]]
});
} );
</script> 
<div id="static">
<h2>Ensembl Genomes Release $eg_version</h2>
<p>Ensembl Genomes species metadata are also available via FTP: <a href="ftp://ftp.ensemblgenomes.org/pub/current/species.txt">Tabular text</a> | <a href="ftp://ftp.ensemblgenomes.org/pub/current/species_metadata.json">JSON</a> | <a href="ftp://ftp.ensemblgenomes.org/pub/current/species_metadata.xml">XML</a></p> 
<table cellpadding="0" cellspacing="0" border="1px dotted #eeeeee"
class="display" id="species_list">
<thead> 
  <tr>
  <th>Species</th><th>Division</th><th>Taxonomy ID</th><th>Assembly</th><th>Genebuild</th><th>Variation</th><th>Pan compara</th><th>Genome alignments</th><th>Other alignments</th>
  </tr>
  </thead>
  <tbody>
ENDHEAD

  for my $md (@{$metadata->{genome}}) {
	my $div_link = $self->{div_links}->{$md->{division}};
	my $div_name = $self->{div_names}->{$md->{division}};
	if (!defined $div_link) {
	  croak "No division defined for $md->{name}";
	}
	$div_link .= $md->{species};
	print $tt2_file join("",
						 ($tr,
						  $td,
						  "<a href='${div_link}'>",
						  $md->{name},
						  '</a>',
						  $tdx,
						  $td,
						  "<a href='",
						  $div_link,
						  "'>",
						  $div_name,
						  '</a>',
						  $td,
						  "<a href='http://www.uniprot.org/taxonomy/" .
							$md->{taxonomy_id} .
							"'>" . $md->{taxonomy_id} . "</a>",
						  $tdx,
						  $td,
						  $md->{assembly_name},
						  $tdx,
						  $td,
						  $md->{genebuild},
						  $tdx,
						  $td,
						  $self->yesno($self->count_variation($md)),
						  $tdx,
						  $td,
						  $self->yesno($md->{pan_species}),
						  $tdx,
						  $td,
						  $self->yesno($self->count_dna_compara($md)),
						  $tdx,
						  $td,
						  $self->yesno($self->count_alignments($md)),
						  $tdx,
						  $trx,
						  "\n"));
  } ## end for my $md (@{$metadata...})
  print $tt2_file <<'ENDFOOT';
</tbody>
<tfoot>
<tr>
  <th>Species</th><th>Division</th><th>Taxonomy ID</th><th>Assembly</th><th>Genebuild</th><th>Variation</th><th>Pan compara</th><th>Genome alignments</th><th>Other alignments</th>
</tr>
</tfoot>
</table>
</div>
ENDFOOT
  close $tt2_file;
  return;
} ## end sub do_dump

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::MetaData::MetaDataDumper::XMLMetaDataDumper

=head1 SYNOPSIS

=head1 DESCRIPTION

implementation to dump metadata details to an XML file

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
