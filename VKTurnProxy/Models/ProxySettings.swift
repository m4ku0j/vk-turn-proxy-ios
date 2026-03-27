import Foundation

class ProxySettings: ObservableObject {
    // Proxy
    @AppStorage("peer")      var peer      = ""
    @AppStorage("vkLink")    var vkLink    = ""
    @AppStorage("threads")   var threads   = 8
    @AppStorage("useUDP")    var useUDP    = true
    @AppStorage("noDtls")    var noDtls    = false
    @AppStorage("localPort") var localPort = "127.0.0.1:9000"
    @AppStorage("rawMode")   var rawMode   = false
    @AppStorage("rawCmd")    var rawCmd    = ""

    // SSH
    @AppStorage("sshIP")           var sshIP           = ""
    @AppStorage("sshPort")         var sshPort         = "22"
    @AppStorage("sshUser")         var sshUser         = "root"
    @AppStorage("sshPass")         var sshPass         = ""
    @AppStorage("sshProxyListen")  var sshProxyListen  = "0.0.0.0:56000"
    @AppStorage("sshProxyConnect") var sshProxyConnect = "127.0.0.1:51820"
}
