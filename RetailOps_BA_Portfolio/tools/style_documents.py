from pathlib import Path
from docx import Document
from docx.shared import Inches,Pt,RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT,WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
R=Path(__file__).resolve().parents[1]/'deliverables'
for p in R.glob('*.docx'):
    d=Document(p)
    sec=d.sections[0]
    sec.top_margin=Inches(.76);sec.bottom_margin=Inches(.7);sec.left_margin=Inches(.82);sec.right_margin=Inches(.82)
    sec.header_distance=Inches(.3);sec.footer_distance=Inches(.38)
    styles=d.styles
    norm=styles['Normal']; norm.font.name='Aptos'; norm.font.size=Pt(9); norm.font.color.rgb=RGBColor(36,52,71)
    norm.paragraph_format.space_after=Pt(5)
    for style,size,space in [('Title',20,8),('Heading 1',15,12),('Heading 2',12,9),('Heading 3',10,6)]:
        if style in styles:
            s=styles[style];s.font.name='Aptos Display';s.font.size=Pt(size);s.font.bold=True
            s.font.color.rgb=RGBColor(16,72,96) if style!='Title' else RGBColor(15,35,56)
            s.paragraph_format.space_before=Pt(space);s.paragraph_format.space_after=Pt(6)
    for table in d.tables:
        table.alignment=WD_TABLE_ALIGNMENT.CENTER
        for i,row in enumerate(table.rows):
            for cell in row.cells:
                cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
                tcPr=cell._tc.get_or_add_tcPr()
                shd=OxmlElement('w:shd');shd.set(qn('w:fill'),'19344A' if i==0 else ('F2F7F9' if i%2==0 else 'FFFFFF'));tcPr.append(shd)
                for para in cell.paragraphs:
                    para.paragraph_format.space_after=Pt(1)
                    for run in para.runs:
                        run.font.name='Aptos';run.font.size=Pt(7.5 if len(table.columns)>4 else 8)
                        if i==0:run.font.bold=True;run.font.color.rgb=RGBColor(255,255,255)
        if table.rows:
            trPr=table.rows[0]._tr.get_or_add_trPr(); rep=OxmlElement('w:tblHeader');rep.set(qn('w:val'),'true');trPr.append(rep)
    head=sec.header.paragraphs[0];head.text='RETAILOPS  /  BUSINESS & SYSTEM ANALYSIS';head.alignment=WD_ALIGN_PARAGRAPH.RIGHT
    for run in head.runs:run.font.size=Pt(7.5);run.font.color.rgb=RGBColor(95,119,134)
    foot=sec.footer.paragraphs[0];foot.text='PORTFOLIO SIMULATION  •  SYNTHETIC DATA  |  '
    foot.alignment=WD_ALIGN_PARAGRAPH.RIGHT
    field=OxmlElement('w:fldSimple');field.set(qn('w:instr'),'PAGE');foot._p.append(field)
    for run in foot.runs:run.font.size=Pt(7);run.font.color.rgb=RGBColor(110,128,145)
    d.save(p)
    print('Styled',p.name,len(d.tables),'tables')
