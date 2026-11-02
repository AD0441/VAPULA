import Darwin
import Foundation
import VapulaCore

/// The kernel releases this advisory lease even after SIGKILL. The lock file is never unlinked:
/// replacing its inode would allow two writers to acquire different locks for the same package.
final class ProjectSession {
  private let descriptor: Int32
  private let marker: URL
  let interrupted: Bool

  init(at package: URL) throws {
    marker = package.appendingPathComponent(".vapula-session")
    descriptor = Darwin.open(package.appendingPathComponent(".vapula-lock").path,
      O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else {
      throw VapulaError.invalid("No se pudo reservar el proyecto para escritura. Revisa los permisos de la carpeta y vuelve a abrirlo.")
    }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      let code = errno
      Darwin.close(descriptor)
      if code == EWOULDBLOCK {
        throw VapulaError.invalid("Este proyecto está abierto en otra instancia de VAPULA. Ciérralo allí y vuelve a intentarlo. No borres los archivos de bloqueo.")
      }
      throw VapulaError.invalid("No se pudo bloquear el proyecto. Conserva el paquete y comprueba sus permisos antes de volver a abrirlo.")
    }
    interrupted = FileManager.default.fileExists(atPath: marker.path)
  }

  func begin() throws {
    try Data(UUID().uuidString.utf8).write(to: marker, options: .atomic)
  }

  func finish() {
    try? FileManager.default.removeItem(at: marker)
  }

  deinit { Darwin.close(descriptor) }
}

public struct ProjectRecoveryNotice: Sendable, Equatable {
  public let interrupted: Bool
  public let verifiedVersions: Int
  public let unreferencedTables: Int
}
