echo "Enter filename:"
read filename

if [ filename != "" ]
then
    now=$(date +"%Y-%m-%dT%H-%M-%S")
    migration="import Foundation
import Fluent

struct $filename: AsyncMigration {
    func prepare(on database: Database) async throws {
        <#code#>
    }

    func revert(on database: Database) async throws {
        <#code#>
    }
}
"
    echo "$migration" > "./Sources/App/Migrations/$now $filename.swift"
fi

