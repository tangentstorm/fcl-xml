{**********************************************************************

    This file is part of the Free Component Library (FCL)

    fpcunit extensions required to run w3.org DOM test suites
    Copyright (c) 2008 by Sergei Gorelkin, sergei_gorelkin@mail.ru

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit domunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DOM, XMLRead, contnrs, fpcunit;

type
{ these two types are separated for the purpose of readability }
  _collection = array of DOMString;   // unordered
  _list = _collection;                // ordered

  TDOMTestBase = class(TTestCase)
  private
    procedure setImplAttr(const name: string; value: Boolean);
    function getImplAttr(const name: string): Boolean;
  protected
    // override for this one is generated by testgen for each descendant
    function GetTestFilesURI: string; virtual;
  protected
    FParser: TDOMParser;
    FAutoFree: TFPObjectList;
    procedure SetUp; override;
    procedure TearDown; override;
    procedure GC(obj: TObject);
    procedure Load(out doc: TDOMDocument; const uri: string);
    function getResourceURI(const res: WideString): WideString;
    function ContentTypeIs(const t: string): Boolean;
    function GetImplementation: TDOMImplementation;
    procedure CheckFeature(const name: string);
    procedure assertNull(const id: string; const ws: DOMString); overload;
    procedure assertEquals(const id: string; exp, act: TObject); overload;
    procedure assertEqualsList(const id: string; const exp: array of DOMString; const act: _list);
    procedure assertEqualsCollection(const id: string; const exp: array of DOMString; const act: _collection);
    procedure assertSame(const id: string; exp, act: TDOMNode);
    procedure assertSize(const id: string; size: Integer; obj: TDOMNodeList);
    procedure assertSize(const id: string; size: Integer; obj: TDOMNamedNodeMap);
    procedure assertInstanceOf(const id: string; obj: TObject; const typename: string);
    procedure assertURIEquals(const id: string;
      const scheme, path, host, file_, name, query, fragment: DOMString;
      IsAbsolute: Boolean; const Actual: DOMString);
    function bad_condition(const TagName: WideString): Boolean;
    property implementationAttribute[const name: string]: Boolean read getImplAttr write setImplAttr;
  end;

procedure _append(var coll: _collection; const Value: DOMString);
procedure _assign(out rslt: _collection; const value: array of DOMString);

implementation

uses
  URIParser;

procedure _append(var coll: _collection; const Value: DOMString);
var
  L: Integer;
begin
  L := Length(coll);
  SetLength(coll, L+1);
  coll[L] := Value;
end;

procedure _assign(out rslt: _collection; const value: array of DOMString);
var
  I: Integer;
begin
  SetLength(rslt, Length(value));
  for I := 0 to High(value) do
    rslt[I] := value[I];
end;

procedure TDOMTestBase.SetUp;
begin
  FParser := TDOMParser.Create;
  FParser.Options.PreserveWhitespace := True;
  FAutoFree := TFPObjectList.Create(True);
end;

procedure TDOMTestBase.TearDown;
begin
  FreeAndNil(FAutoFree);
  FreeAndNil(FParser);
end;

procedure TDOMTestBase.GC(obj: TObject);
begin
  FAutoFree.Add(obj);
end;

procedure TDOMTestBase.assertSame(const id: string; exp, act: TDOMNode);
begin
  if exp <> act then
  begin
    assertNotNull(id, exp);
    assertNotNull(id, act);
    assertEquals(id, exp.nodeType, act.nodeType);
    assertEquals(id, exp.nodeValue, act.nodeValue);
  end;
end;

procedure TDOMTestBase.assertNull(const id: string; const ws: DOMString);
begin
  if ws <> '' then
    Fail(id);
end;

procedure TDOMTestBase.assertEquals(const id: string; exp, act: TObject);
begin
  inherited assertSame(id, exp, act);
end;

procedure TDOMTestBase.assertEqualsList(const id: string;
  const exp: array of DOMString; const act: _list);
var
  I: Integer;
begin
  AssertEquals(id, Length(exp), Length(act));
  // compare ordered
  for I := 0 to High(exp) do
    AssertEquals(id, exp[I], act[I]);
end;

procedure TDOMTestBase.assertEqualsCollection(const id: string; const exp: array of DOMString; const act: _collection);
var
  I, J, matches: Integer;
begin
  AssertEquals(id, Length(exp), Length(act));
  // compare unordered
  for I := 0 to High(exp) do
  begin
    matches := 0;
    for J := 0 to High(act) do
      if act[J] = exp[I] then
        Inc(matches);
    AssertTrue(id+': no match found for <'+exp[I]+'>', matches <> 0);
    AssertTrue(id+': multiple matches for <'+exp[I]+'>', matches = 1);
  end;
end;

procedure TDOMTestBase.assertSize(const id: string; size: Integer; obj: TDOMNodeList);
begin
  AssertNotNull(id, obj);
  AssertEquals(id, size, obj.Length);
end;

procedure TDOMTestBase.assertSize(const id: string; size: Integer; obj: TDOMNamedNodeMap);
begin
  AssertNotNull(id, obj);
  AssertEquals(id, size, obj.Length);
end;

function TDOMTestBase.getResourceURI(const res: WideString): WideString;
var
  Base, Level: WideString;
begin
  Base := GetTestFilesURI + 'files/';
  if not ResolveRelativeURI(Base, res+'.xml', Result) then
    Result := '';
end;

function TDOMTestBase.getImplAttr(const name: string): Boolean;
begin
  if name = 'expandEntityReferences' then
    result := FParser.Options.ExpandEntities
  else if name = 'validating' then
    result := FParser.Options.Validate
  else if name = 'namespaceAware' then
    result := FParser.Options.Namespaces
  else if name = 'ignoringElementContentWhitespace' then
    result := not FParser.Options.PreserveWhitespace
  else
  begin
    Fail('Unknown implementation attribute: ''' + name + '''');
    result := False;
  end;
end;

procedure TDOMTestBase.setImplAttr(const name: string; value: Boolean);
begin
  if name = 'validating' then
    FParser.Options.Validate := value
  else if name = 'expandEntityReferences' then
    FParser.Options.ExpandEntities := value
  else if name = 'coalescing' then
  // TODO: action unknown yet
  else if (name = 'signed') and value then
    Ignore('Setting implementation attribute ''signed'' to ''true'' is not supported')
  else if name = 'hasNullString' then
  // TODO: probably we cannot support this
  else if name = 'namespaceAware' then
    FParser.Options.Namespaces := value
  else if name = 'ignoringElementContentWhitespace' then
    FParser.Options.PreserveWhitespace := not value
  else
    Fail('Unknown implementation attribute: ''' + name + '''');
end;

procedure TDOMTestBase.Load(out doc: TDOMDocument; const uri: string);
var
  t: TXMLDocument;
begin
  doc := nil;
  FParser.ParseURI(getResourceURI(uri), t);
  doc := t;
  GC(t);
end;

procedure TDOMTestBase.assertInstanceOf(const id: string; obj: TObject; const typename: string);
begin
  AssertTrue(id, obj.ClassNameIs(typename));
end;

// TODO: This is a very basic implementation, needs to be completed.
procedure TDOMTestBase.assertURIEquals(const id: string; const scheme, path,
  host, file_, name, query, fragment: DOMString; IsAbsolute: Boolean;
  const Actual: DOMString);
var
  URI: TURI;
begin
  AssertTrue(id, Actual <> '');
  URI := ParseURI(utf8Encode(Actual));
  AssertEquals(id, URI.Document, utf8Encode(file_));
end;

function TDOMTestBase.bad_condition(const TagName: WideString): Boolean;
begin
  Fail('Unsupported condition: '+ TagName);
  Result := False;
end;

function TDOMTestBase.ContentTypeIs(const t: string): Boolean;
begin
{ For now, claim only xml as handled content.
  This may be extended with html and svg.
}
  result := (t = 'text/xml');
end;

function TDOMTestBase.GetImplementation: TDOMImplementation;
begin
  result := nil;
end;

procedure TDOMTestBase.CheckFeature(const name: string);
begin
  // purpose/action is currently unknown
end;

function TDOMTestBase.GetTestFilesURI: string;
begin
  result := '';
end;

end.
