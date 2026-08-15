#include <stdio.h>
#include <unistd.h>

int main(void) {
    int a, b;
    char c;
    char name[50];
    
    printf("how are you? ");
    scanf("%49s", name);
    printf("Hello %s", name);
    fflush(stdout);
    sleep(1);
    
    printf("\nbtw %s", name);
    usleep(500000);
    
    for(int i = 0; i < 6; i += 2) {
        fflush(stdout);
        usleep(250000);
        printf("\nlarp larp larp sahur");
    }
    
    printf("\n");
    usleep(500000);
    
    printf("Also %s, give 'a' a value: ", name);
    scanf("%d", &a);
    
    printf("Nice! Now %s, give 'b' a value: ", name);
    scanf("%d", &b);
    
    int valid = 0;
    while (!valid) {
        printf("Good boy, now %s, choose an operation (+-/*): ", name);
        scanf(" %c", &c);
        
        if(c == '+') {
            printf("a + b = %d\n", a + b);
            valid = 1;
        }
        else if(c == '-') {
            printf("a - b = %d\n", a - b);
            valid = 1;
        }
        else if(c == '/') {
            printf("a / b = %d\n", a / b);
            valid = 1;
        }
        else if(c == '*') {
            printf("a * b = %d\n", a * b);
            valid = 1;
        }
        else {
            printf("\n");
            printf("choose one of the operations!\n");
            printf("choose one of the operations!\n");
            printf("choose one of the operations!\n");
            printf("choose one of the operations!\n");
            printf("choose one of the operations!\n");
            int ch;
            sleep(1);
            while ((ch = getchar()) != '\n' && ch != EOF);
        }
    }
    
    return 0;
}
