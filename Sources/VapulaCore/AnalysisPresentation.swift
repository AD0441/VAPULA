import Foundation

extension AnalysisMethod {
  public var title: String {
    switch self {
    case .descriptive: "Descriptiva"
    case .oneSampleT: "t de una muestra"
    case .pairedT: "t de muestras pareadas"
    case .welch: "t de Welch · dos grupos"
    case .anova: "ANOVA de un factor"
    case .mannWhitney: "U de Mann–Whitney"
    case .chiSquare: "Chi-cuadrado de independencia"
    case .pearson: "Correlación de Pearson"
    case .spearman: "Correlación de Spearman"
    case .regression: "Regresión lineal simple"
    }
  }
  public var needsPair: Bool {
    [.pairedT, .pearson, .spearman, .regression, .chiSquare].contains(self)
  }
  public var needsTwoGroups: Bool { [.welch, .mannWhitney].contains(self) }
  public var needsGrouping: Bool { needsTwoGroups || self == .anova }
  public var supportsAlpha: Bool {
    [.oneSampleT, .pairedT, .welch, .anova, .mannWhitney, .chiSquare].contains(self)
  }
  public var explanation: String {
    switch self {
    case .descriptive:
      "Resume centro y dispersión: n, media, mediana, cuartiles tipo 7 y variación muestral (n−1). Úsala antes de contrastar hipótesis."
    case .oneSampleT:
      "Compara la media de una variable con un valor de referencia. H0: μ = μ0. Requiere observaciones independientes y normalidad aproximada de la media; reporta diferencia, t, gl, p bilateral e intervalo."
    case .pairedT:
      "Compara dos mediciones de las mismas unidades. H0: media(X−Y)=0. Solo se incluyen pares completos; verifica independencia entre unidades y normalidad aproximada de las diferencias."
    case .welch:
      "Compara dos grupos independientes sin exigir varianzas iguales. H0: μA=μB. Reporta diferencia A−B, t, gl de Welch–Satterthwaite, p bilateral, IC y d_av."
    case .anova:
      "Compara medias de dos o más grupos independientes. H0: todas las medias son iguales. ANOVA clásico exige varianzas comparables y residuales aproximadamente normales; un resultado global no identifica qué grupos difieren."
    case .mannWhitney:
      "Contrasta distribuciones de dos grupos independientes mediante rangos. Aproximación bilateral con empates y continuidad; no equivale automáticamente a comparar medianas. Con muestras pequeñas se requiere especial cautela."
    case .chiSquare:
      "Contrasta independencia entre dos variables categóricas. Pearson sin corrección de Yates. Las celdas con frecuencias esperadas bajas limitan la aproximación; la app informa esa advertencia."
    case .pearson:
      "Mide asociación lineal de dos variables sobre pares completos. Revisa escala, independencia, linealidad y valores extremos. Se muestra el coeficiente, sin p-valor."
    case .spearman:
      "Mide asociación monótona mediante Pearson sobre rangos medios en empates. Se muestra el coeficiente, sin p-valor. Una asociación no implica causalidad."
    case .regression:
      "Ajusta una recta con covarianzas centradas, sin invertir X'X. Informa pendiente, intercepto, R² y escala residual. Revisa independencia, linealidad, homocedasticidad y residuales."
    }
  }
}
extension AnalysisSpecification {
  public var variableSummary: String {
    if method.needsGrouping {
      return "\(x) · \(group)" + (method.needsTwoGroups ? ": \(groupA) / \(groupB)" : "")
    }
    if method.needsPair { return "\(x) / \(y)" }
    if method == .oneSampleT { return "\(x) · μ0 = \(hypothesizedMean ?? 0)" }
    return x
  }
}
