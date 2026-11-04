#!/usr/bin/env python3
"""Generate editable Graphviz ERD, PNG diagrams and BPMN 2.0 XML with DI layout.
Run from anywhere; Graphviz `dot` must be available for PNGs.
"""
from pathlib import Path
import re, subprocess, xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
SCHEMA=(ROOT/'database/01_schema.sql').read_text()
TABLES=re.findall(r'CREATE TABLE dbo\.(\w+) \(',SCHEMA)
FKs=[('Cities','Countries'),('Stores','Cities'),('Warehouses','Cities'),
('Customers','Countries'),('CustomerAddresses','Customers'),('CustomerAddresses','Cities'),
('Categories','Categories'),('Products','Categories'),('Suppliers','Countries'),
('SupplierProducts','Suppliers'),('SupplierProducts','Products'),
('Inventory','Warehouses'),('Inventory','Products'),('InventoryMovements','Inventory'),
('SalesOrders','Customers'),('SalesOrders','CustomerAddresses'),('SalesOrders','Stores'),
('SalesOrderItems','SalesOrders'),('SalesOrderItems','Products'),
('InventoryReservations','SalesOrderItems'),('InventoryReservations','Warehouses'),
('OrderFulfillments','SalesOrders'),('OrderFulfillments','Warehouses'),
('FulfillmentItems','OrderFulfillments'),('FulfillmentItems','SalesOrderItems'),
('Shipments','OrderFulfillments'),('Shipments','Carriers'),
('PurchaseOrders','Suppliers'),('PurchaseOrders','Warehouses'),
('PurchaseOrderItems','PurchaseOrders'),('PurchaseOrderItems','Products'),
('GoodsReceipts','PurchaseOrderItems'),('ReturnRequests','SalesOrders'),
('ReturnItems','ReturnRequests'),('ReturnItems','SalesOrderItems')]
assert len(TABLES)==25,(len(TABLES),TABLES)
GROUPS={'Geo & People':['Countries','Cities','Stores','Warehouses','Customers','CustomerAddresses'],
'Catalog & Supply':['Categories','Products','Suppliers','SupplierProducts'],
'Orders & Fulfillment':['SalesOrders','SalesOrderItems','InventoryReservations','OrderFulfillments','FulfillmentItems','Carriers','Shipments'],
'Inventory & Procurement':['Inventory','InventoryMovements','PurchaseOrders','PurchaseOrderItems','GoodsReceipts'],
'Returns & Audit':['ReturnRequests','ReturnItems','AuditEvents']}
colors=['#f0f6ff','#f3f9f5','#fff8ed','#f6f3ff','#fff2f2']
lines=['digraph RetailOps {','graph [rankdir=LR, splines=polyline, overlap=false, nodesep=0.36, ranksep=1.0, bgcolor="white", fontsize=22, label="RetailOps | Relational System Overview (25 tables)", labelloc=t, fontname="Arial"];','node [shape=box, style="rounded,filled", color="#475569", penwidth=1, fillcolor="white", fontname="Arial", fontsize=10, margin="0.1,0.08"];','edge [color="#94a3b8", arrowsize=0.5, penwidth=0.8];']
for i,(name,tables) in enumerate(GROUPS.items()):
    lines+= [f'subgraph cluster_{i} {{ label="{name}"; bgcolor="{colors[i]}"; color="#cbd5e1"; style="rounded"; fontname="Arial";']
    lines += [f'"{t}";' for t in tables]
    lines += ['}']
for a,b in FKs:
    if a!=b: lines.append(f'"{b}" -> "{a}" [color="#a1a1aa"];')
lines.append('}')
dot='\n'.join(lines)
(ROOT/'system-design/01_ERD.dot').write_text(dot)
try:
 subprocess.run(['dot','-Tpng',str(ROOT/'system-design/01_ERD.dot'),'-o',str(ROOT/'assets/retailops_erd.png')],check=True,timeout=40)
 print('Created ERD PNG')
except Exception as e: print('Diagram PNG unavailable',e)
md=['# Logical ERD — all 25 tables','',
'**Editable source:** `01_ERD.dot` (Graphviz). **Rendered preview:** `../assets/retailops_erd.png`.','',
'The arrows point from parent to child. This is a relationship overview; read `07_data_dictionary.md` for column-level types and constraints.','',
'![ERD](../assets/retailops_erd.png)','',
'## Primary relationship list','']
md += [f'- `{p}` → `{c}`' for c,p in FKs]
md += ['','**Important implementation details:** Composite FK `(WarehouseID,ProductID)` from `InventoryMovements` to `Inventory`; many-to-many products/suppliers via `SupplierProducts`; many-to-many order items/warehouses via `InventoryReservations` and `FulfillmentItems`; `AuditEvents` uses polymorphic references intentionally and therefore has no entity FK.','']
(ROOT/'system-design/01_ERD.md').write_text('\n'.join(md))
# Data dictionary from schema: parse CREATE TABLE bodies by start boundaries, not nested CHECK parentheses.
blocks=re.findall(r'CREATE TABLE dbo\.(\w+) \((.*?)\n\);',SCHEMA,flags=re.S)
dict_lines=['# SQL data dictionary (generated from schema)','',
'**Canonical source:** `database/01_schema.sql`. SQL Server types are shown as authored. All tables belong to `dbo`.','']
for name,body in blocks:
    dict_lines += [f'## {name}','','| Column | Type | Nullable | Notes |','|---|---|---|---|']
    for s in body.splitlines():
        s=s.strip()
        if not s or s.startswith('CONSTRAINT ') or s.startswith(')'): continue
        m=re.match(r'(\w+)\s+([A-Z]+(?:\([\d,]+\))?)\s+(.*)',s)
        if not m: continue
        col,typ,attrs=m.groups()
        attrs=attrs.rstrip(',')
        nullable='YES' if re.search(r'\bNULL\b',attrs) and not re.search(r'\bNOT\s+NULL\b',attrs) else 'NO'
        desc=[]
        if 'IDENTITY' in attrs: desc.append('Identity')
        if 'PRIMARY KEY' in attrs: desc.append('PK')
        if 'REFERENCES' in attrs: desc.append('FK')
        if 'UNIQUE' in attrs: desc.append('Unique')
        if 'DEFAULT' in attrs: desc.append('Default')
        if 'CHECK' in attrs: desc.append('Check')
        dict_lines.append(f'| {col} | `{typ}` | {nullable} | {", ".join(desc)} |')
    dict_lines.append('')
(ROOT/'system-design/07_data_dictionary.md').write_text('\n'.join(dict_lines))
# BPMN2 XML with shapes/edges and laneSet. BPMN XSD-style namespaces.
BN='http://www.omg.org/spec/BPMN/20100524/MODEL'
BD='http://www.omg.org/spec/BPMN/20100524/DI'
DI='http://www.omg.org/spec/DD/20100524/DI'
DC='http://www.omg.org/spec/DD/20100524/DC'
ET.register_namespace('bpmn',BN); ET.register_namespace('bpmndi',BD); ET.register_namespace('di',DI); ET.register_namespace('dc',DC)
root=ET.Element(f'{{{BN}}}definitions',{'id':'Definitions_RetailOps','targetNamespace':'https://example.invalid/retailops/bpmn'})
process=ET.SubElement(root,f'{{{BN}}}process',{'id':'Process_OrderToDelivery','name':'RetailOps — Order to delivery (TO-BE)','isExecutable':'false'})
lanes=[('Sales_lane','Sales channel','Start','Validate'),('Inventory_lane','Inventory service','CheckStock','GatewayStock','Reserve','Reject'),('Warehouse_lane','Warehouse operations','CreateFulfillment','Dispatch'),('Carrier_lane','Courier / support','ConfirmDelivery','EndSuccess','EndFailure')]
ls=ET.SubElement(process,f'{{{BN}}}laneSet',{'id':'LaneSet1'})
for laneid,label,*nodes in lanes:
    lane=ET.SubElement(ls,f'{{{BN}}}lane',{'id':laneid,'name':label})
    for n in nodes: ET.SubElement(lane,f'{{{BN}}}flowNodeRef').text=n
nodes=[('startEvent','Start','Order received',120,92,36,36),
('task','Validate','Validate order + address',245,87,140,46),
('task','CheckStock','Read available stock',420,199,140,50),
('exclusiveGateway','GatewayStock','All lines available?',600,197,55,55),
('task','Reserve','Atomically reserve stock',700,199,155,50),
('task','CreateFulfillment','Create warehouse fulfillments',885,324,170,52),
('task','Dispatch','Dispatch + decrement stock',1090,324,165,52),
('task','ConfirmDelivery','Confirm delivered timestamp',1290,455,160,52),
('endEvent','EndSuccess','Delivered',1500,463,36,36),
('task','Reject','Reject: no stock / rollback',705,92,160,50),
('endEvent','EndFailure','Order remains NEW',930,96,36,36)]
flow=[('Start','Validate',''),('Validate','CheckStock',''),('CheckStock','GatewayStock',''),
('GatewayStock','Reserve','Yes'),('GatewayStock','Reject','No'),('Reserve','CreateFulfillment',''),
('CreateFulfillment','Dispatch',''),('Dispatch','ConfirmDelivery',''),('ConfirmDelivery','EndSuccess',''),('Reject','EndFailure','')]
for kind,n,label,x,y,w,h in nodes:
    e=ET.SubElement(process,f'{{{BN}}}{kind}',{'id':n,'name':label})
    for idx,(a,b,lab) in enumerate(flow):
        flowid=f'Flow_{idx+1}'
        if b==n: ET.SubElement(e,f'{{{BN}}}incoming').text=flowid
        if a==n: ET.SubElement(e,f'{{{BN}}}outgoing').text=flowid
for i,(a,b,label) in enumerate(flow):
    attrs={'id':f'Flow_{i+1}','sourceRef':a,'targetRef':b}
    if label: attrs['name']=label
    ET.SubElement(process,f'{{{BN}}}sequenceFlow',attrs)
diagram=ET.SubElement(root,f'{{{BD}}}BPMNDiagram',{'id':'BPMNDiagram1'})
plane=ET.SubElement(diagram,f'{{{BD}}}BPMNPlane',{'id':'BPMNPlane1','bpmnElement':'Process_OrderToDelivery'})
for kind,n,label,x,y,w,h in nodes:
    shape=ET.SubElement(plane,f'{{{BD}}}BPMNShape',{'id':f'{n}_di','bpmnElement':n})
    ET.SubElement(shape,f'{{{DC}}}Bounds',{'x':str(x),'y':str(y),'width':str(w),'height':str(h)})
pos={n:(x,y,w,h) for kind,n,label,x,y,w,h in nodes}
for i,(a,b,label) in enumerate(flow):
    ax,ay,aw,ah=pos[a]; bx,by,bw,bh=pos[b]
    edge=ET.SubElement(plane,f'{{{BD}}}BPMNEdge',{'id':f'Flow_{i+1}_di','bpmnElement':f'Flow_{i+1}'})
    points=[(ax+aw,ay+ah/2),(bx,by+bh/2)]
    for x,y in points: ET.SubElement(edge,f'{{{DI}}}waypoint',{'x':str(x),'y':str(y)})
bpmn_path=ROOT/'system-design/02_process_to_be.bpmn'
ET.ElementTree(root).write(bpmn_path,encoding='utf-8',xml_declaration=True)
# Documentation + preview with Graphviz
pp=['digraph process {','graph [rankdir=LR, bgcolor="white", nodesep=0.55, ranksep=0.8, labelloc=t, label="RetailOps | TO-BE order fulfillment", fontname="Arial", fontsize=18];',
'node [shape=box, style="rounded,filled", fillcolor="#eef2ff", color="#475569", fontname="Arial", fontsize=10];']
for kind,n,label,*_ in nodes:
    shape='diamond' if kind=='exclusiveGateway' else ('oval' if 'Event' in kind or n.startswith('End') else 'box')
    pp.append(f'"{n}" [label="{label}", shape={shape}];')
for a,b,lab in flow:
    pp.append(f'"{a}" -> "{b}"'+(f' [label="{lab}"]' if lab else '')+';')
pp.append('}')
(ROOT/'system-design/02_process_to_be.dot').write_text('\n'.join(pp))
try: subprocess.run(['dot','-Tpng',str(ROOT/'system-design/02_process_to_be.dot'),'-o',str(ROOT/'assets/to_be_process.png')],check=True,timeout=40)
except Exception as e: print('BPMN preview unavailable',e)
print('25 tables,',len(FKs),'relationships; BPMN XML and dictionary generated')
