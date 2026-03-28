import Foundation

@Observable
final class GitViewModel {
    var gitInfo: GitInfo?
    var gitDetails: GitDetails?
    var isLoading = false

    func loadGitInfo(projectPath: String) async {
        isLoading = true
        defer { isLoading = false }
        let url = URL(fileURLWithPath: projectPath)
        gitInfo = await GitService.getGitInfo(projectPath: url)
        gitDetails = await GitService.getGitDetails(projectPath: url)
    }
}
