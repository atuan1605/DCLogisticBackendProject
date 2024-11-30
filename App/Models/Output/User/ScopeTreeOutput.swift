import Foundation
import Vapor

struct ScopeTreeOutput: Content {
    var id: String
    var label: String
    var isChecked: Bool
    var children: [ScopeTreeOutput]?
}

extension User.Scope {
    func toTree() -> ScopeTreeOutput {
        let trackingItemsTree = ScopeTreeOutput(
            id: "trackingItems",
            label: "Danh sách Tracking",
            isChecked: self.contains(.trackingItems)
            )
        let updateTrackingItemsTree = ScopeTreeOutput(
            id: "updateTrackingItems",
            label: "Sửa thông tin Tracking",
            isChecked: self.contains(.updateTrackingItems)
            )
        
        let usInventoryTree = ScopeTreeOutput(
            id: "usInventory",
            label: "Danh sách Tracking tại kho US",
            isChecked: self.contains(.usInventory)
            )
        let usWarehouseTree = ScopeTreeOutput(
            id: "usWarehouse",
            label: "Chỉnh sửa Tracking tại kho US",
            isChecked: self.contains(.usWarehouse),
            children: [
                usInventoryTree,
                updateTrackingItemsTree,
                trackingItemsTree
            ])
        
        let shipmentListTree = ScopeTreeOutput(
            id: "shipmentList",
            label: "Danh sách Chuyến/Thùng US",
            isChecked: self.contains(.shipmentList)
            )
        let packShipmentTree = ScopeTreeOutput(
            id: "packShipment",
            label: "Chỉnh sửa Chuyến/Thùng US",
            isChecked: self.contains(.packShipment)
            )
        let shipmentTree = ScopeTreeOutput(
            id: "shipments",
            label: "Chỉnh sửa Chuyến/Thùng + Tracking US",
            isChecked: self.contains(.shipments),
            children: [
                shipmentListTree,
                packShipmentTree,
                trackingItemsTree,
                updateTrackingItemsTree
            ])
        
        let usTree = ScopeTreeOutput(
            id: "usAppAccess",
            label: "US Admin",
            isChecked: self.contains(.usAppAccess),
            children: [
                shipmentTree,
                usWarehouseTree
            ])
        
        let customersTree = ScopeTreeOutput(
            id: "customers",
            label: "Danh sách khách hàng",
            isChecked: self.contains(.customers)
            )
        let updateCustomersTree = ScopeTreeOutput(
            id: "updateCustomers",
            label: "Chỉnh sửa danh sách khách hàng",
            isChecked: self.contains(.updateCustomers)
            )
        
        let vnInventoryTree = ScopeTreeOutput(
            id: "vnInventory",
            label: "Danh sách Tracking VN",
            isChecked: self.contains(.vnInventory)
            )
        let vnWarehouseTree = ScopeTreeOutput(
            id: "vnWarehouse",
            label: "Chỉnh sửa Tracking tại kho VN",
            isChecked: self.contains(.vnWarehouse),
            children: [
                vnInventoryTree,
                updateTrackingItemsTree,
                trackingItemsTree
            ])
        
        let deliveryListTree = ScopeTreeOutput(
            id: "deliveryList",
            label: "Danh sách chuyến VN",
            isChecked: self.contains(.deliveryList)
            )
        let packDeliveryTree = ScopeTreeOutput(
            id: "packDelivery",
            label: "Chỉnh sửa chuyến/thùng VN",
            isChecked: self.contains(.packDelivery)
            )
        let deliveriesTree = ScopeTreeOutput(
            id: "deliveries",
            label: "Chỉnh sửa chuyến/thùng + Tracking VN",
            isChecked: self.contains(.deliveries),
            children: [
                deliveryListTree,
                packDeliveryTree
            ])
        
        let vnAppAccessTree =  ScopeTreeOutput(
            id: "vnAppAccess",
            label: "Danh sách khách hàng + Chỉnh sửa chuyến/thùng + Tracking VN",
            isChecked: self.contains(.vnAppAccess),
            children: [
                customersTree,
                vnWarehouseTree,
                deliveriesTree
            ])
        
        let vnTree =  ScopeTreeOutput(
            id: "vnAppAdmin",
            label: "VN Admin + chỉnh sửa danh sách khách hàng",
            isChecked: self.contains(.vnAppAdmin),
            children: [
                vnAppAccessTree,
                updateCustomersTree
            ])
        let userListTree = ScopeTreeOutput(
            id: "userList",
            label: "Danh sách User",
            isChecked: self.contains(.userList)
            )
        let updateUsersTree = ScopeTreeOutput(
            id: "updateUsers",
            label: "Chỉnh sửa User",
            isChecked: self.contains(.updateUsers)
            )
        let usersTree =  ScopeTreeOutput(
            id: "users",
            label: "Danh sách + Chỉnh sửa User",
            isChecked: self.contains(.users),
            children: [
                userListTree,
                updateUsersTree
            ])
        let verifyBuyerTree = ScopeTreeOutput(
            id: "verifyBuyer",
            label: "Kích hoạt Buyer",
            isChecked: self.contains(.verifyBuyer)
            )
        let editPackingRequestLeftTree = ScopeTreeOutput(
            id: "editPackingRequestLeft",
            label: "Chỉnh sửa yêu cầu đặc biệt",
            isChecked: self.contains(.editPackingRequestLeft)
            )
        let buyerTree = ScopeTreeOutput(
            id: "buyers",
            label: "Kích hoạt + Chỉnh sửa yêu cầu đặc biệt Buyer",
            isChecked: self.contains(.buyers),
            children: [
                verifyBuyerTree,
                editPackingRequestLeftTree
            ])
        let warehouseListTree = ScopeTreeOutput(
            id: "warehouseList",
            label: "Danh sách kho",
            isChecked: self.contains(.warehouseList)
        )
        let updateWarehouseTree = ScopeTreeOutput(
            id: "updateWarehouse",
            label: "Chỉnh sửa Kho",
            isChecked: self.contains(.updateWarehouse)
        )
        let warehouseTree = ScopeTreeOutput(
            id: "warehouses",
            label: "Danh sách + Chỉnh sửa Kho",
            isChecked: self.contains(.warehouses),
            children: [
                warehouseListTree,
                updateWarehouseTree
            ])
        let agentTrackingTree = ScopeTreeOutput(
            id: "agentTracking",
            label: "Thống kê tracking",
            isChecked: self.contains(.agentTracking)
        )
        let cameraTree = ScopeTreeOutput(
            id: "camera",
            label: "Trích xuất video",
            isChecked: self.contains(.camera)
        )
        let updateAgentTree = ScopeTreeOutput(
            id: "updateAgent",
            label: "Chỉnh sửa Đại lý",
            isChecked: self.contains(.updateAgent)
        )
        let agentListTree = ScopeTreeOutput(
            id: "agentList",
            label: "Danh sách Đại lý",
            isChecked: self.contains(.agentList)
        )
        let agentTree = ScopeTreeOutput(
            id: "agents",
            label: "Danh sách + Chỉnh sửa Đại lý",
            isChecked: self.contains(.warehouses),
            children: [
                agentListTree,
                updateAgentTree
            ])

        return ScopeTreeOutput(
            id: "allAccess",
            label: "Toàn bộ quyền Truy cập",
            isChecked: self.contains(.allAccess),
            children: [
                usTree,
                vnTree,
                usersTree,
                buyerTree,
                warehouseTree,
                agentTrackingTree,
                cameraTree,
                agentTree
            ])
    }

    init(from tree: ScopeTreeOutput) {
        var scope: User.Scope = .init(rawValue: 0)
        func searchTree(node: ScopeTreeOutput) {
            if node.isChecked {
                var nodeScope: User.Scope? = nil
                switch node.id {
                case "allAccess":
                    nodeScope = .allAccess
                case "camera":
                    nodeScope = .camera
                case "updateAgent":
                    nodeScope = .updateAgent
                case "agentList":
                    nodeScope = .agentList
                case "agents":
                    nodeScope = .agents
                case "vnAppAdmin":
                    nodeScope = .vnAppAdmin
                case "users":
                    nodeScope = .users
                case "vnAppAccess":
                    nodeScope = .vnAppAccess
                case "deliveries":
                    nodeScope = .deliveries
                case "packDelivery":
                    nodeScope = .packDelivery
                case "deliveryList":
                    nodeScope = .deliveryList
                case "vnWarehouse":
                    nodeScope = .vnWarehouse
                case "vnInventory":
                    nodeScope = .vnInventory
                case "updateCustomers":
                    nodeScope = .updateCustomers
                case "customers":
                    nodeScope = .customers
                case "usAppAccess":
                    nodeScope = .usAppAccess
                case "shipments":
                    nodeScope = .shipments
                case "shipmentList":
                    nodeScope = .shipmentList
                case "packShipment":
                    nodeScope = .packShipment
                case "usWarehouse":
                    nodeScope = .usWarehouse
                case "usInventory":
                    nodeScope = .usInventory
                case "updateTrackingItems":
                    nodeScope = .updateTrackingItems
                case "trackingItems":
                    nodeScope = .trackingItems
                case "userList":
                    nodeScope = .userList
                case "updateUsers":
                    nodeScope = .updateUsers
                case "verifyBuyer":
                    nodeScope = .verifyBuyer
                case "editPackingRequestLeft":
                    nodeScope = .editPackingRequestLeft
                case "buyers":
                    nodeScope = .buyers
                case "warehouseList":
                    nodeScope = .warehouseList
                case "updateWarehouse":
                    nodeScope = .updateWarehouse
                case "warehouses":
                    nodeScope = .warehouses
                case "agentTracking":
                    nodeScope = .agentTracking
                    
                default:
                    break
                }
                if let validScope = nodeScope {
                    scope.insert(validScope)
                }
            }
            node.children?.forEach { child in
                searchTree(node: child)
            }
        }
        self = scope
    }
}
