import Foundation
import Testing
import VapulaCore
import VapulaData
import VapulaReports

struct ExpandedWorkflowTests {
  @Test func newGeneralTestsUseTheSelectedVersionAndExplicitExclusions() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("vapula-general-\(UUID())")
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
    let source=root.appendingPathComponent("sample.csv")
    try Data("g,x,y,c1,c2\nA,1,2,R,X\nA,2,2,R,Y\nA,4,3,R,X\nB,5,7,S,Y\nB,6,8,S,Y\nB,8,7,S,X\nC,9,10,R,X\nC,10,13,S,Y\nC,12,15,R,Y\nC,,16,,X\n".utf8).write(to:source)
    let engine=DataEngine();_=try await engine.create(at:root.appendingPathComponent("p.vapula"),name:"General tests")
    let v=try await engine.importFile(source,options:ImportOptions())
    let specs=[AnalysisSpecification(method:.oneSampleT,x:"x",hypothesizedMean:5),AnalysisSpecification(method:.pairedT,x:"x",y:"y"),AnalysisSpecification(method:.anova,x:"x",group:"g"),AnalysisSpecification(method:.mannWhitney,x:"x",group:"g",groupA:"A",groupB:"B"),AnalysisSpecification(method:.chiSquare,x:"c1",y:"c2")]
    for s in specs {
      let result=try await engine.analyze(datasetID:v.id,specification:s)
      #expect(result.datasetID==v.id);#expect(result.specification==s)
      let expected=s.method == .mannWhitney ? 6:9
      #expect(result.validCount==expected);#expect(result.excludedCount==10-expected)
      let p=try #require(result.metrics["p_two_sided"] ?? result.metrics["p_value"]);#expect((0...1).contains(p))
    }
    let p=try await engine.snapshot();#expect(p.results.count==5)
    let pdf=try PDFReport.data(project:p);#expect(pdf.starts(with:Data("%PDF-".utf8)))
    #expect(try await engine.groupLabels(datasetID:v.id,column:"g")==["A","B","C"])
    await engine.close()
  }
  @Test func chartStylesPersistWithProjectAndHistogramUsesRequestedBins() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("vapula-style-\(UUID())")
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
    let source=root.appendingPathComponent("sample.csv");try Data(("x,y\n"+(1...40).map{"\($0),\($0*2)"}.joined(separator:"\n")+"\n").utf8).write(to:source)
    let engine=DataEngine(),url=root.appendingPathComponent("p.vapula");_=try await engine.create(at:url,name:"Style")
    let v=try await engine.importFile(source,options:ImportOptions())
    var style=ChartConfiguration();style.kind = .scatter;style.palette = .custom;style.customColorHex="#783DA8";style.binCount=8;style.title="Synthetic scatter"
    try await engine.saveChartConfiguration(datasetID:v.id,configuration:style)
    let bins=try await engine.histogram(datasetID:v.id,column:"x",bins:8)
    #expect(bins.count<=8);#expect(bins.reduce(0){$0+$1.y}==40)
    await engine.close();let reopened=try await engine.open(at:url)
    #expect(reopened.chartConfigurations?[v.id.uuidString]==style)
    await engine.close()
  }
  @Test func earlierSchemaOneProjectsWithoutOptionalPresentationFieldsStillDecode() throws {
    let p=VapulaProject(name:"Original schema one")
    var json=try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(p)) as? [String:Any])
    json.removeValue(forKey:"chartConfigurations")
    let decoded=try JSONDecoder().decode(VapulaProject.self,from:JSONSerialization.data(withJSONObject:json))
    #expect(decoded.schemaVersion==1);#expect(decoded.chartConfigurations==nil);#expect(decoded.name==p.name)
  }
}
