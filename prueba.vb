Imports System 
Imports System.IO

Module Program 
	Sub Main(args As String()) 
		Console.WriteLine("==========================================================") 
		Console.WriteLine(" Este codigo lo que hace es leer un archivo") 
		Console.WriteLine("==========================================================") 
		'Declaracion de variables 
		Dim LecturaArchivo As IO.StreamReader 
		Dim Lineatexto As String 
		Dim Bandera As Boolean = False 
		Dim NombreArchivo As String = "curso.txt"
		
		'Realiza la lectura del archivo 
		LecturaArchivo = New IO.StreamReader(NombreArchivo) 
		Try 
			While Not Bandera 
				Lineatexto = LecturaArchivo.ReadLine() 
				If Lineatexto Is Nothing Then 
					Bandera = True 
				Else Console.WriteLine(Lineatexto) 
				End If 
			End While 
			'Se cierra el archivo 
			LecturaArchivo.Close() 
		Catch problema As Exception 
			Console.WriteLine("Ha ocurrido un inconveniente " + problema.Message()) 
		End Try 
		Console.WriteLine("==========================================================")
	End Sub 
End Module 
'Fin del código para leer un archivo