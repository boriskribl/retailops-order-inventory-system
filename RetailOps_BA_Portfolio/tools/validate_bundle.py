#!/usr/bin/env python3
"""Portable static bundle checks. Does NOT execute T-SQL or validate a PBIX file."""
from pathlib import Path
from xml.etree import ElementTree as ET
import re, json, csv
p=Path(__file__).resolve().parents[1]
schema=(p/'database/01_schema.sql').read_text()
procs=(p/'database/02_procedures.sql').read_text()
views=(p/'database/05_views.sql').read_text()
assert len(re.findall(r'CREATE TABLE dbo\.\w+',schema))==25
assert len(re.findall(r'CREATE OR ALTER PROCEDURE dbo\.\w+',procs))==7
assert len(re.findall(r'CREATE OR ALTER VIEW dbo\.\w+',views))==5
for item in ['usp_CreateOrder','usp_AllocateOrder','usp_DispatchFulfillment','usp_MarkShipmentDelivered','usp_CancelOrder','usp_ReceivePurchaseOrderItem','usp_ReceiveReturn']:
    assert item in procs
assert 'SET @FulfillmentID=NULL' in procs  # guard against stale loop value in split allocation
assert 'SET @OrderID=NULL' in procs        # guard against stale OUT variable
assert 'THROW 51009' in procs and '@ExistingOrderID' in procs  # payload-aware retries
assert 'PASS N03' in (p/'testing/02_negative_tests.sql').read_text()
check=(p/'testing/04_post_install_validation.sql').read_text()
assert all(f'PASS V{i:02d}' in check for i in range(1,8))
ET.parse(p/'system-design/02_process_to_be.bpmn')
json.loads((p/'powerbi/03_RetailOps_theme.json').read_text())
with (p/'business-analysis/05_requirements_traceability.csv').open(newline='') as f:
    rows=list(csv.DictReader(f))
assert len(rows)>=15
for req in rows:
    assert req['RequirementID'] and req['SQLImplementation'] and req['TestID']
assert (p/'assets/retailops_erd.png').stat().st_size>10000
assert (p/'deliverables/RetailOps_Business_Requirements_Document.docx').stat().st_size>10000
assert (p/'deliverables/RetailOps_System_Requirements_Specification.docx').stat().st_size>10000
assert (p/'deliverables/RetailOps_Interview_Case_Study.pptx').stat().st_size>10000
assert (p/'QUALITY_REVIEW.md').exists()
assert (p/'WINDOWS_SETUP_GITHUB_SR.md').exists()
assert (p/'tools/run_on_windows.ps1').exists()
print('PASS STATIC v1.1: 25 tables, 7 procedures, 5 views, N03 idempotency guard, V01-V07 checks, BPMN/theme/traceability and document assets.')
print('NOT TESTED: T-SQL execution, SQL Server integration/performance/concurrency, Power BI refresh, production security.')
