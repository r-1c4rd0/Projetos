package com.comercio.petsphere.model

abstract class Usuario(
    open var login: String,
    open var senha: String
) {
    override fun toString(): String {
        return super.toString()
    }

    abstract fun adicionarUsuario()
    abstract fun atualizarUsuario()
    abstract fun deleteUsuario()
}
