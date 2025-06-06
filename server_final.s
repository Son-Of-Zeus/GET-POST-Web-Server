.intel_syntax noprefix
.global _start
_start:

# socket(AF_INET, SOCK_STREAM, IPPROTO_IP)
mov rdi, 2             
mov rsi, 1           
mov rdx, 0            
mov rax, 41             
syscall
mov rbx, rax           

# bind(server_fd, sockaddr_in, 16)
mov word ptr [rsp], 2       
mov word ptr [rsp+2], 0x5000 
mov dword ptr [rsp+4], 0   
mov qword ptr [rsp+8], 0    
mov rdi, rbx
mov rsi, rsp
mov rdx, 16
mov rax, 49            
syscall

# listen(server_fd, 5)
mov rdi, rbx
mov rsi, 0             
mov rax, 50           
syscall

main_loop:
# accept(server_fd, NULL, NULL)
mov rdi, rbx
xor rsi, rsi
xor rdx, rdx
mov rax, 43           
syscall
mov r15, rax           

# Fork the process
mov rax, 57             
syscall
cmp rax, 0
je child_process

# Parent: close client socket and loop
mov rdi, r15
mov rax, 3             
syscall
jmp main_loop

child_process:
# Close server socket in child
mov rdi, rbx
mov rax, 3              
syscall

# Allocate buffer for request (8KB)
sub rsp, 8192
mov r14, rsp            

# Read HTTP request
mov rdi, r15            
mov rsi, r14            
mov rdx, 8192         
mov rax, 0             
syscall
mov r12, rax           
jle send_response       

# Parse request to find URL path
mov rcx, r14           
mov r13, r14
add r13, r12            

# Find first space (after "POST")
find_first_space:
cmp byte ptr [rcx], 0x20
je found_first_space
inc rcx
cmp rcx, r13
jb find_first_space
jmp send_response     

found_first_space:
inc rcx                
mov r10, rcx          

# Find second space (end of path)
find_second_space:
cmp byte ptr [rcx], 0x20
je found_second_space
inc rcx
cmp rcx, r13
jb find_second_space
jmp send_response       

found_second_space:
mov r9, rcx            
sub r9, r10             
cmp r9, 0
je send_response       

# Copy path to new buffer
sub rsp, 256
mov r11, rsp            
mov rcx, r9
mov rsi, r10
mov rdi, r11
copy_path:
mov al, byte ptr [rsi]
mov byte ptr [rdi], al
inc rsi
inc rdi
dec rcx
jnz copy_path
mov byte ptr [rdi], 0

#Find whether it is GET OR POST
mov al, byte ptr [r14]
cmp al, 'G'
je get_process
cmp al, 'P'
je post_process
jmp send_response

post_process:
# Find end of headers (\r\n\r\n)
mov r14,rsp
mov rcx, r14
find_headers_end:   
mov eax, dword ptr [rcx]
cmp eax, 0x0a0d0a0d     
je found_headers_end
inc rcx
jmp find_headers_end

found_headers_end:
add rcx, 4              
mov r8, r13
sub r8, rcx
lea r9,[rcx]
jle send_response      

# Open file for writing 
mov rdi, r11         
mov rsi, 0x41         
mov rdx, 511           
mov rax, 2             
syscall
mov r10, rax            
cmp rax, 0
jl send_response        

# Write body to file
mov rdi, r10
mov rsi, r9         
mov rdx, r8             
mov rax, 1             
syscall

# Close file
mov rdi, r10
mov rax, 3             
syscall
call send_response
jmp close_exit


get_process:
    mov rdi, r11     
    mov rsi, 0       
    mov rax, 2       
    syscall
    mov r10, rax
    cmp rax, 0
    jl send_response    

    # Read file into buffer
    sub rsp, 256        
    mov rdi, r10
    mov rsi, rsp
    mov rdx, 256
    mov rax, 0
    syscall
    mov r12, rax        
    mov rbx, rsp       

    # Close file
    mov rdi, r10
    mov rax, 3
    syscall    

    sub rsp, 19
    mov byte ptr [rsp], 'H'
    mov byte ptr [rsp+1], 'T'
    mov byte ptr [rsp+2], 'T'
    mov byte ptr [rsp+3], 'P'
    mov byte ptr [rsp+4], '/'
    mov byte ptr [rsp+5], '1'
    mov byte ptr [rsp+6], '.'
    mov byte ptr [rsp+7], '0'
    mov byte ptr [rsp+8], ' '
    mov byte ptr [rsp+9], '2'
    mov byte ptr [rsp+10], '0'
    mov byte ptr [rsp+11], '0'
    mov byte ptr [rsp+12], ' '
    mov byte ptr [rsp+13], 'O'
    mov byte ptr [rsp+14], 'K'
    mov byte ptr [rsp+15], '\r'
    mov byte ptr [rsp+16], '\n'
    mov byte ptr [rsp+17], '\r'
    mov byte ptr [rsp+18], '\n'
    mov rdi, r15            
    mov rsi, rsp
    mov rdx, 19
    mov rax, 1              
    syscall

    # Send file contents
    mov rdi, r15        
    mov rsi, rbx        
    mov rdx, r12        
    mov rax, 1
    syscall
    jmp close_exit
    
 # Send HTTP headers
send_response:
# Write HTTP/1.0 200 OK response
sub rsp, 19
mov byte ptr [rsp], 'H'
mov byte ptr [rsp+1], 'T'
mov byte ptr [rsp+2], 'T'
mov byte ptr [rsp+3], 'P'
mov byte ptr [rsp+4], '/'
mov byte ptr [rsp+5], '1'
mov byte ptr [rsp+6], '.'
mov byte ptr [rsp+7], '0'
mov byte ptr [rsp+8], ' '
mov byte ptr [rsp+9], '2'
mov byte ptr [rsp+10], '0'
mov byte ptr [rsp+11], '0'
mov byte ptr [rsp+12], ' '
mov byte ptr [rsp+13], 'O'
mov byte ptr [rsp+14], 'K'
mov byte ptr [rsp+15], '\r'
mov byte ptr [rsp+16], '\n'
mov byte ptr [rsp+17], '\r'
mov byte ptr [rsp+18], '\n'
mov rdi, r15            
mov rsi, rsp
mov rdx, 19
mov rax, 1              
syscall

close_exit:

# Exit child process
mov rdi, 0
mov rax, 60            
syscall

