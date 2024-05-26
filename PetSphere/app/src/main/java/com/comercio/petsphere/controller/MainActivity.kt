package com.comercio.petsphere.controller

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.comercio.petsphere.ui.theme.PetSphereTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            PetSphereTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    MainScreen()
                }
            }
        }
    }
}

@Composable
fun MainScreen() {
    val buttons = listOf(
        ButtonData(text = "Perfil", onClick = { /* TODO: Handle Perfil click */ }, padding = 18.dp),
        ButtonData(text = "Exercícios", onClick = { /* TODO: Handle Exercícios click */ }, padding = 8.dp),
        ButtonData(text = "Veterinário", onClick = { /* TODO: Handle Veterinário click */ }, padding = 8.dp),
        ButtonData(text = "Nutrição", onClick = { /* TODO: Handle Nutrição click */ }, padding = 18.dp)
    )

    Box(
        modifier = Modifier.fillMaxSize()
    ) {
        Greeting("Pet Sphere")
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            contentAlignment = Alignment.BottomEnd
        ) {
            FloatingActionButtonGroup(buttons = buttons)
        }
    }
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Box(
        contentAlignment = Alignment.TopCenter,
        modifier = modifier.fillMaxSize()
    ) {
        Text(
            text = "Bem vindos ao $name!",
            modifier = modifier
        )
    }
}

@Composable
fun FloatingActionButtonGroup(buttons: List<ButtonData>) {
    Column(
        horizontalAlignment = Alignment.End,
        verticalArrangement = Arrangement.spacedBy(16.dp) // Espacamento entre os botões
    ) {
        buttons.forEach { button ->
            FloatingActionButton(
                onClick = button.onClick,
                modifier = Modifier.align(Alignment.End)
            ) {
                Text(text = button.text, modifier = Modifier.padding(button.padding))
            }
        }
    }
}

data class ButtonData(
    val text: String,
    val onClick: () -> Unit,
    val padding: Dp
)

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    PetSphereTheme {
        MainScreen()
    }
}