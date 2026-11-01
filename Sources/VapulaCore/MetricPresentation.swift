import Foundation

public enum MetricPresentation {
  /// Omit redundant API aliases from human-facing tables; CSV preserves every key.
  public static func visibleKeys(_ metrics: [String: Double]) -> [String] {
    metrics.keys.filter { key in
      if key == "difference_ci_lower", metrics[key] == metrics["ci_lower"] { return false }
      if key == "difference_ci_upper", metrics[key] == metrics["ci_upper"] { return false }
      if key == "n_pairs", metrics["n"] != nil { return false }
      return true
    }.sorted()
  }
  public static func title(_ key: String) -> String {
    let labels = [
      "mean": "Media", "median": "Mediana", "minimum": "Mínimo", "maximum": "Máximo",
      "range": "Rango", "sample_sd": "Desviación estándar muestral",
      "sample_variance": "Varianza muestral", "n": "Observaciones válidas",
      "missing_or_nonfinite": "Ausentes / no finitos", "q1": "Primer cuartil",
      "q3": "Tercer cuartil", "iqr": "Rango intercuartílico", "p_two_sided": "p bilateral",
      "p_value": "p del contraste", "t": "Estadístico t", "f": "Estadístico F",
      "df": "Grados de libertad", "df_between": "gl entre grupos",
      "df_within": "gl dentro de grupos", "ci_lower": "Límite inferior IC",
      "ci_upper": "Límite superior IC", "difference_a_minus_b": "Diferencia A − B",
      "mean_difference": "Diferencia de medias", "mean_a": "Media A", "mean_b": "Media B",
      "n_a": "n grupo A", "n_b": "n grupo B", "cohen_d_av": "Cohen d_av", "cohen_d": "Cohen d",
      "cohen_d_z": "Cohen d_z", "eta_squared": "Eta cuadrado", "cramers_v": "V de Cramér",
      "chi_square": "Chi-cuadrado", "minimum_expected": "Frecuencia esperada mínima",
      "expected_below_5": "Celdas con esperado < 5", "expected_below_1": "Celdas con esperado < 1",
      "pearson_r": "Pearson r", "spearman_rho": "Spearman ρ", "slope": "Pendiente",
      "intercept": "Intercepto", "r_squared": "R²", "residual_sd": "Desviación residual",
      "slope_se": "Error estándar de pendiente", "u_a": "U grupo A", "u_b": "U grupo B",
      "rank_biserial_a_minus_b": "Correlación biserial de rangos A − B",
      "standard_error": "Error estándar", "groups": "Número de grupos",
      "difference_ci_lower": "Límite inferior IC de la diferencia",
      "difference_ci_upper": "Límite superior IC de la diferencia",
      "hypothesized_mean": "Media de referencia μ₀", "sample_mean": "Media muestral",
      "ss_between": "Suma de cuadrados entre grupos", "ss_within": "Suma de cuadrados dentro de grupos",
      "ms_between": "Cuadrado medio entre grupos", "ms_within": "Cuadrado medio dentro de grupos",
      "grand_mean": "Media global", "z_corrected": "Estadístico z corregido",
      "tie_groups": "Grupos de empates", "tied_observations": "Observaciones empatadas",
      "continuity_correction": "Corrección de continuidad", "minimum_group_n": "n del grupo más pequeño",
      "expected_below_5_fraction": "Fracción de celdas con esperado < 5",
      "yates_correction": "Corrección de Yates (0: no aplicada)",
      "rows": "Categorías por fila", "columns": "Categorías por columna",
      "residual_sum_squares": "Suma de cuadrados residual",
      "difference_sd": "Desviación de las diferencias", "mean_x": "Media X", "mean_y": "Media Y",
      "n_pairs": "Pares completos", "reference_mean": "Media de referencia μ₀",
    ]
    return labels[key] ?? key.replacingOccurrences(of: "_", with: " ")
  }
}
