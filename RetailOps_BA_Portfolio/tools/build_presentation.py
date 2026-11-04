#!/usr/bin/env python3
from pathlib import Path
from pptx import Presentation
from pptx.util import Inches,Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'deliverables/RetailOps_Interview_Case_Study.pptx'
prs=Presentation(); prs.slide_width=Inches(13.33);prs.slide_height=Inches(7.5)
NAVY=RGBColor(19,39,58); TEAL=RGBColor(15,118,110); WHITE=RGBColor(255,255,255)
SOFT=RGBColor(244,248,250); BLUE=RGBColor(37,99,235); GRAY=RGBColor(94,110,125)
AMBER=RGBColor(224,149,48); RED=RGBColor(173,70,62)
def rect(sl,x,y,w,h,fill,rad=False,line=None):
    shape=sl.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if rad else MSO_SHAPE.RECTANGLE,Inches(x),Inches(y),Inches(w),Inches(h))
    shape.fill.solid();shape.fill.fore_color.rgb=fill
    shape.line.fill.background() if line is None else None
    if line is not None:shape.line.color.rgb=line
    return shape
def txt(sl,x,y,w,h,t,size=17,color=NAVY,bold=False,align=None):
    sh=sl.shapes.add_textbox(Inches(x),Inches(y),Inches(w),Inches(h));tf=sh.text_frame;tf.word_wrap=True
    tf.margin_left=Inches(.02);tf.margin_right=Inches(.02);tf.margin_top=Inches(.02)
    p=tf.paragraphs[0];p.text=t;p.font.name='Aptos';p.font.size=Pt(size);p.font.bold=bold;p.font.color.rgb=color
    if align: p.alignment=align
    return sh
def base(title,n,subtitle=''):
    sl=prs.slides.add_slide(prs.slide_layouts[6]);rect(sl,0,0,13.33,7.5,WHITE)
    rect(sl,0,0,.14,7.5,TEAL)
    txt(sl,.48,.35,12, .55,title,27,NAVY,True)
    if subtitle:txt(sl,.5,1.05,12,.42,subtitle,12,GRAY)
    rect(sl,.5,7.03,12.35,.018,RGBColor(219,229,233))
    txt(sl,.52,7.11,10,.22,'RETAILOPS  /  INDEPENDENT FICTIONAL PORTFOLIO CASE  /  SYNTHETIC DATA',8,GRAY)
    txt(sl,12.3,7.11,.5,.2,str(n),9,GRAY,align=PP_ALIGN.RIGHT)
    return sl
def card(sl,x,y,w,h,heading,body,bar=TEAL):
    rect(sl,x,y,w,h,SOFT,rad=True)
    rect(sl,x,y,.07,h,bar)
    txt(sl,x+.21,y+.18,w-.4,.43,heading,17,NAVY,True)
    txt(sl,x+.21,y+.72,w-.42,h-.8,body,13,GRAY)
# 1 cover
s=prs.slides.add_slide(prs.slide_layouts[6]);rect(s,0,0,13.33,7.5,NAVY)
rect(s,.65,.87,.12,5.5,TEAL)
txt(s,1.02,1.18,11,1.4,'RetailOps',54,WHITE,True)
txt(s,1.05,2.4,11,1.4,'Enterprise Order & Inventory\nManagement System',34,WHITE,True)
txt(s,1.05,4.45,10,.6,'Business Analysis  ·  System Design  ·  SQL Server  ·  BI',18,RGBColor(176,233,222))
rect(s,1.04,5.48,4.8,.57,TEAL,rad=True)
txt(s,1.23,5.59,4.55,.35,'Independent, fictional portfolio project',15,WHITE,True)
txt(s,1.03,6.8,10,.3,'All outcomes are simulated; technical tests require execution on SQL Server.',10,RGBColor(178,198,208))
# 2
s=base('01  |  The business problem',2,'A hypothetical retailer operating across Serbia, Croatia and Slovenia')
card(s,.62,1.73,3.85,3.38,'Stock visibility','Different channels may see different availability; the business risks overselling and cancellations.',TEAL)
card(s,4.73,1.73,3.85,3.38,'Fulfillment delays','Manual inter-warehouse decisions and isolated courier records make promises difficult to meet.',BLUE)
card(s,8.84,1.73,3.85,3.38,'Decision blind spots','Fragmented reporting makes margin, late shipment, returns and reorder decisions inconsistent.',AMBER)
txt(s,.77,5.65,11.8,.8,'Objective: translate these assumptions into measurable, testable system requirements — not just a database schema.',19,NAVY,True)
# 3
s=base('02  |  Discovery, scope & stakeholders',3,'What a Business Analyst defines before the first SQL table')
card(s,.63,1.69,5.8,3.73,'Stakeholders','Operations sponsor · Warehouse manager · E-commerce product owner · Finance analyst · Procurement lead · DBA / QA')
card(s,6.75,1.69,5.8,3.73,'Scope boundary','IN: orders, stock reservation, fulfillment, receiving, returns, KPI views.\n\nOUT: payments, live APIs, VAT/FX, RBAC, client-facing frontend.',BLUE)
rect(s,.65,5.72,12,.76,RGBColor(232,246,242),rad=True)
txt(s,.9,5.91,11.4,.45,'Business artifacts: BRD  ·  SRS  ·  User stories  ·  RACI/RAID  ·  KPI dictionary',17,TEAL,True)
# 4
s=base('03  |  AS-IS → TO-BE process',4,'The model shows how requirements connect to the future operational workflow')
card(s,.7,1.75,5.64,4.4,'AS-IS (assumed)','Spreadsheet stock check\n→ Emails to warehouses\n→ Manual stock hold\n→ Courier portal\n→ Weekly spreadsheet report',RED)
card(s,6.75,1.75,5.64,4.4,'TO-BE (proposed)','Validate order + address\n→ Domestic-first inventory allocation\n→ Atomic stock reservation\n→ Warehouse shipment + ledger\n→ On-time delivery & BI views',TEAL)
# 5
s=base('04  |  Traceability from need to evidence',5,'Business problem → requirement → design → implementation → acceptance test')
head=['Business need','Requirement','System component','Verification']
val=['Stop overselling','FR-03 / US-03\nAtomic allocation','usp_AllocateOrder\nUPDLOCK + HOLDLOCK','N01 insufficient stock\nC01 concurrent last unit']
for i in range(4):
    x=.65+i*3.16
    rect(s,x,2.08,2.92,2.54,SOFT,rad=True)
    rect(s,x,2.08,2.92,.55,TEAL if i<3 else BLUE)
    txt(s,x+.15,2.18,2.65,.34,head[i],15,WHITE,True)
    txt(s,x+.17,2.91,2.58,1.3,val[i],17,NAVY,i==0)
    if i<3: txt(s,x+2.95,3.03,.4,.45,'→',23,TEAL,True)
txt(s,.77,5.23,11.7,.78,'Traceability is what makes this more than a collection of SQL commands.',20,NAVY,True)
# 6
s=base('05  |  Relational architecture',6,'25 tables across geographies, catalog, orders, fulfillment, inventory, procurement and returns')
png=str(ROOT/'assets/retailops_erd.png')
s.shapes.add_picture(png,Inches(2.65),Inches(1.44),width=Inches(7.9),height=Inches(5.42))
# 7
s=base('06  |  Most important technical rule',7,'A successful allocation reserves ALL required quantities — or NONE')
for i,(h,b) in enumerate([('1. Validate','Check order, lines and shipping address.'),('2. Lock','Acquire update/range locks on candidate stock.'),('3. Reserve','Prefer domestic stock; split across warehouses if required.'),('4. Commit / rollback','Commit once fully allocated. Otherwise undo the entire attempt.')]):
    x=.72+(i%2)*6.15;y=1.7+(i//2)*2.0
    card(s,x,y,5.76,1.76,h,b,TEAL if i<3 else AMBER)
txt(s,.79,6.04,11.8,.55,'On hand changes at DISPATCH. Reservation changes at ALLOCATION. Different business events.',17,NAVY,True)
# 8
s=base('07  |  Decision-oriented reporting',8,'Views → Power BI build kit → KPI definitions (no built PBIX yet)')
card(s,.7,1.8,3.79,3.7,'Sales Performance','Net revenue (delivered only)\nMargin %\nReturn rate\nMarket and category trends',TEAL)
card(s,4.79,1.8,3.79,3.7,'Inventory & Supply','Available units\nReorder exceptions\nInventory value\nSupplier outstanding units',BLUE)
card(s,8.88,1.8,3.79,3.7,'Fulfillment','On-time delivery %\nOverdue open shipments\nAverage delivery hours\nCarrier / country comparison',AMBER)
txt(s,.82,5.87,11.9,.56,'Important: 100,000 orders are SYNTHETIC. Business outcomes are not real observed improvements.',16,RED,True)
# 9
s=base('08  |  Testing, transparency & next steps',9,'Professional analysis includes explicit unknowns and verifiable acceptance evidence')
card(s,.65,1.75,5.83,3.8,'Authored / prepared','25-table schema · 7 procedures · 100k-order generator · 5 views · SQL integration and negative tests · BPMN/ERD · BRD/SRS',TEAL)
card(s,6.78,1.75,5.83,3.8,'Must still be verified','Run all SQL scripts in SSMS\nCapture T01–T07, N01–N02 and concurrency C01\nBuild and refresh the PBIX\nRecord real query timings',AMBER)
rect(s,.72,5.82,11.93,.59,RGBColor(230,239,246),rad=True)
txt(s,.9,5.97,11.7,.38,'Production extensions: FX + VAT · API / RBAC · Backorders · SLA-cost routing · Monitoring',15,NAVY,True)
prs.save(OUT)
print(OUT,len(prs.slides),'slides')
